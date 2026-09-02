################################################################################
# HERRAMIENTA UNIVERSAL V15 (RESUMEN COMPLETO: MEDIA, DISPERSIÓN, MEDIANA E IC95%)
################################################################################

if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse, minpack.lm, boot, readxl, openxlsx)

cat("\n====================================================================")
cat("\n   ANALIZADOR DE TPCs V14.2: MEDIA + DISPERSIÓN + MEDIANA + IC95%")
cat("\n====================================================================\n")

# 1. CONFIGURACIÓN INICIAL
cat("\n[PASO 1]: Selecciona tu archivo Excel...")
file_path <- file.choose(); setwd(dirname(file_path)) 
df_raw <- read_excel(file_path)

col_temp <- readline("-> Nombre columna TEMPERATURA: ")
col_sp   <- readline("-> Nombre columna ESPECIE/ID: ")
col_perf_input <- readline("-> Variables RENDIMIENTO (ej. SBM, PI): ")
col_perf <- trimws(unlist(strsplit(col_perf_input, ",")))
prefijo <- readline("-> Prefijo para archivos de salida: ")

iter_r <- as.numeric(readline("-> ¿Iteraciones Bootstrap? (200 sugerido): "))
if(is.na(iter_r)) iter_r <- 200

# 2. OPCIÓN DE DISPERSIÓN PARA LA MEDIA
cat("\n COMPLETA LAS OPCIONES DE DISPERSIÓN PARA LA TABLA DE RESUMEN")
cat("\n[!] Elige la medida de dispersión clásica:")
cat("\n    1. SE (Error Estándar) | 2. SD (Desviación) | 3. VAR (Varianza)")
medida_opt <- readline("Selección: ")
sufijo <- switch(medida_opt, "1" = "se", "2" = "sd", "3" = "var", "sd")
disp_func <- switch(medida_opt, 
                    "1" = function(x) sd(x, na.rm=T)/sqrt(sum(!is.na(x))), 
                    "2" = function(x) sd(x, na.rm=T), 
                    "3" = function(x) var(x, na.rm=T), sd)

# 3. CONFIGURACIÓN DE GRÁFICOS Y GUARDADO
marcar_topt <- toupper(readline("-> ¿Marcar T-Óptima (Vertical)? (S/N): ")) == "S"
marcar_pmax <- toupper(readline("-> ¿Marcar P-Máximo (Horizontal)? (S/N): ")) == "S"

cat("\n¿Qué rango de Breadth quieres sombrear?")
cat("\n   1. TB80 | 2. TB50 | 3. Ninguno")
breadth_opt <- readline("Selección: ")

cat("\n[PASO 3]: Opciones de guardado:")
g_plots    <- toupper(readline("-> ¿Guardar gráficos (PNG)? (S/N): ")) == "S"
g_excel    <- toupper(readline("-> ¿Guardar tabla resumen (Excel)? (S/N): ")) == "S"
g_boot_raw <- toupper(readline("-> ¿Guardar bootstrap crudo (Excel)? (S/N): ")) == "S"

# 4. FUNCIONES DE MODELADO
briere_model <- function(T, Tmin, Tmax, a) {
  res <- a * T * (T - Tmin) * sqrt(pmax(0, Tmax - T))
  res[T < Tmin | T > Tmax] <- 0  
  return(res)
}

get_all_params <- function(data, indices) {
  d <- data[indices, ]
  colnames(d)[2] <- "Perf"
  t_min_obs <- min(d$TEMP, na.rm = TRUE); t_max_obs <- max(d$TEMP, na.rm = TRUE)
  
  fit <- try(nlsLM(Perf ~ briere_model(TEMP, Tmin, Tmax, a), data = d,
                   start = list(Tmin = t_min_obs - 2, Tmax = t_max_obs + 2, a = 0.01),
                   lower = c(Tmin = -15, Tmax = 15, a = 0), 
                   upper = c(Tmin = 40, Tmax = 70, a = 10),
                   control = nls.lm.control(maxiter = 100)), silent = TRUE)
  
  if (inherits(fit, "try-error")) return(rep(NA, 16))
  
  p <- coef(fit); t_seq <- seq(-10, 75, length.out = 1500)
  perf <- briere_model(t_seq, p["Tmin"], p["Tmax"], p["a"])
  Pmax <- max(perf, na.rm = TRUE); Topt <- t_seq[which.max(perf)]
  
  perf_opt <- briere_model(Topt, p["Tmin"], p["Tmax"], p["a"])
  perf_sub <- briere_model(Topt - 5, p["Tmin"], p["Tmax"], p["a"])
  q10_val  <- if(!is.na(perf_sub) && perf_sub > 0) perf_opt / perf_sub else NA
  
  auc_val <- try(integrate(briere_model, lower = p["Tmin"], upper = p["Tmax"], 
                           Tmin = p["Tmin"], Tmax = p["Tmax"], a = p["a"])$value, silent = TRUE)
  if(inherits(auc_val, "try-error")) auc_val <- NA
  
  calc_lims <- function(thresh) {
    target <- Pmax * thresh; idx <- which(perf >= target)
    if(length(idx) > 0) return(c(t_seq[min(idx)], t_seq[max(idx)], t_seq[max(idx)] - t_seq[min(idx)]))
    return(c(NA, NA, NA))
  }
  p80 <- calc_lims(0.80); p50 <- calc_lims(0.50)
  
  return(c(q10_val, p["a"], p["Tmax"], p["Tmax"] - Topt, Topt, Pmax, Pmax*0.5, 
           p50[1], p50[2], Pmax*0.8, p80[1], p80[2], p80[3], p50[3], p["Tmin"], auc_val))
}

# 5. PROCESAMIENTO DE DATOS Y CONSTRUCCIÓN DE LA TABLA COMPLETA
df <- df_raw %>% rename(TEMP = all_of(col_temp), sp_num = all_of(col_sp)) %>% mutate(TEMP = as.numeric(TEMP))
especies <- unique(df$sp_num)
p_names <- c("Q10", "Cm", "Tth", "d", "Topt", "Pmax", "P50", "T50_min", "T50_max", "P80", "T80_min", "T80_max", "TB_80", "TB_50", "Tmin_ajust", "AUC")

resultados_list <- list(); t_resumen <- list(); t_boot_crudo <- list()

cat("\n[!] Analizando y calculando métricas integradas...\n")

for (esp in especies) {
  for (v in col_perf) {
    temp_data <- df %>% filter(sp_num == esp) %>% select(TEMP, Perf = all_of(v)) %>% drop_na()
    if(nrow(temp_data) < 7) next
    
    cat(paste("    > Procesando:", esp, "[", v, "]... "))
    res_boot <- try(boot(data = temp_data, statistic = get_all_params, R = iter_r), silent = TRUE)
    
    if(!inherits(res_boot, "try-error")) {
      res_df <- as.data.frame(res_boot$t) %>% drop_na()
      colnames(res_df) <- p_names
      
      # Métricas Tradicionales
      f_mean <- colMeans(res_df, na.rm = TRUE)
      f_disp <- sapply(res_df, disp_func)
      
      # Métricas No Paramétricas
      f_median <- sapply(res_df, median, na.rm = TRUE)
      ic_low   <- sapply(res_df, quantile, probs = 0.025, na.rm = TRUE)
      ic_high  <- sapply(res_df, quantile, probs = 0.975, na.rm = TRUE)
      
      # Tabla Resumen Consolidada (Incluye todo)
      fila_res <- data.frame(Especie = esp, Variable = v)
      for(n in p_names) {
        # Tradicionales
        fila_res[[paste0(n, "_mean")]] <- f_mean[n]
        fila_res[[paste0(n, "_", sufijo)]] <- f_disp[n]
        
        # Nuevas
        fila_res[[paste0(n, "_median")]] <- f_median[n]
        fila_res[[paste0(n, "_CI2.5")]]   <- ic_low[n]
        fila_res[[paste0(n, "_CI97.5")]]  <- ic_high[n]
      }
      t_resumen[[paste(esp, v)]] <- fila_res
      
      if(g_boot_raw) {
        t_boot_crudo[[paste(esp, v)]] <- res_df %>% mutate(Especie = esp, Variable = v)
      }
      
      resultados_list[[paste(esp, v)]] <- list(boot = res_df, data = temp_data, esp = esp, v = v, f = f_median)
      cat("OK.\n")
    } else { cat("Error.\n") }
  }
}

# 6. GENERACIÓN DE GRÁFICOS (EVALUACIÓN PUNTO POR PUNTO + IC95%)
cat("\n[!] Generando figuras finales......\n")

t_grid <- seq(-10, 65, length.out = 1000)

for (item in resultados_list) {
  boot_matrix <- item$boot
  
  eval_matrix <- apply(boot_matrix, 1, function(p) {
    briere_model(t_grid, p["Tmin_ajust"], p["Tth"], p["Cm"])
  })
  
  curva_banda <- data.frame(
    T = t_grid,
    P_median = apply(eval_matrix, 1, median, na.rm = TRUE),
    P_low    = apply(eval_matrix, 1, quantile, probs = 0.025, na.rm = TRUE),
    P_high   = apply(eval_matrix, 1, quantile, probs = 0.975, na.rm = TRUE)
  ) %>% filter(P_median > 0 | P_high > 0)
  
  p_max_rojo <- max(curva_banda$P_median, na.rm = TRUE)
  t_opt_rojo <- curva_banda$T[which.max(curva_banda$P_median)]
  
  target_p <- if(breadth_opt == "1") p_max_rojo * 0.8 else p_max_rojo * 0.5
  idx_breadth <- which(curva_banda$P_median >= target_p)
  
  y_lim <- max(c(max(curva_banda$P_high), max(item$data$Perf)), na.rm = TRUE) * 1.15
  
  g <- ggplot()
  
  # Banda IC95%
  g <- g + geom_ribbon(data = curva_banda, aes(x = T, ymin = P_low, ymax = P_high), 
                       fill = "grey75", alpha = 0.4)
  
  # Sombreado Breadth
  if(breadth_opt %in% c("1", "2") && length(idx_breadth) > 0) {
    t_min_b <- curva_banda$T[min(idx_breadth)]
    t_max_b <- curva_banda$T[max(idx_breadth)]
    g <- g + geom_rect(aes(xmin = t_min_b, xmax = t_max_b, ymin = 0, ymax = target_p), 
                       fill = ifelse(breadth_opt=="1", "forestgreen", "orange"), alpha = 0.25)
  }
  
  # Curva central (Mediana) + Puntos
  g <- g + geom_line(data = curva_banda, aes(x = T, y = P_median), color = "firebrick", linewidth = 1.3) +
    geom_point(data = item$data, aes(x = TEMP, y = Perf), alpha = 0.7, size = 3)
  
  if(marcar_topt) g <- g + geom_vline(xintercept = t_opt_rojo, linetype = "dashed", color = "darkblue", alpha = 0.8)
  if(marcar_pmax) g <- g + geom_hline(yintercept = p_max_rojo, linetype = "dotted", color = "darkred", alpha = 0.8)
  
  g <- g + scale_y_continuous(limits = c(0, y_lim), expand = c(0,0)) +
    scale_x_continuous(limits = c(min(curva_banda$T)-1, max(curva_banda$T)+2), expand = c(0,0)) +
    theme_classic(base_size = 14) + 
    labs(title = paste("ID:", item$esp), 
         subtitle = paste("Variable:", item$v, "| Línea: Mediana, Banda: IC95%"), 
         x = "Temperatura (°C)", y = item$v)
  
  if(g_plots) ggsave(paste0(prefijo, "_", item$esp, "_", item$v, ".png"), plot = g, width = 8, height = 6)
}

# 7. EXPORTACIÓN FINAL
cat("\n[!] Generando tablas de resumen y bootstrap...\n")
if(g_excel && length(t_resumen) > 0) {
  write.xlsx(bind_rows(t_resumen), paste0(prefijo, "_Resumen_Final.xlsx"))
}
if(g_boot_raw && length(t_boot_crudo) > 0) {
  write.xlsx(bind_rows(t_boot_crudo), paste0(prefijo, "_Bootstrap_Completo.xlsx"))
}

cat("\n\n--- PROCESO COMPLETADO EXITOSAMENTE ---")

