
{
################################################################################
# HERRAMIENTA UNIVERSAL V13
################################################################################

if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse, minpack.lm, boot, readxl, openxlsx)

cat("\n====================================================================")
cat("\n   ANALIZADOR DE TPCs V13: AUTOGUIADO")
cat("\n====================================================================\n")
}
{
# 1. CONFIGURACIÓN INICIAL
# SELECCION DEL ARCHIVO CON LOS DATOS
cat("\n[PASO 1]: Selecciona tu archivo Excel...")
file_path <- file.choose(); setwd(dirname(file_path)) 
df_raw <- read_excel(file_path)
}

# CARGAR LOS NOMBRE DE LAS VARIABLES A ANALIZAR
{
cat("\nCARGAR EL NOMBRE DE LA COLUMNA QUE CONTIENE LOS NIVELES TERMICOS EXPERIMENTALES")
col_temp <- readline("-> Nombre columna TEMPERATURA: ")
}
{
cat("\nCARGAR EL NOMBRE DE LA COLUMNA QUE CONTIENE LA IDENTIFICACION DE LAS ESPECIES SI HAY MAS DE UNA")
col_sp   <- readline("-> Nombre columna ESPECIE/ID: ")
}
{
cat("\nCARGAR EL NOMBRE DE LA COLUMNA QUE CONTIENE LA VARIABLES DE RENDIMIENTO, UNA VARIABLE O VARIAS")
col_perf_input <- readline("-> Variables RENDIMIENTO (ej. SBM, PI): ")
}
{
cat("\n DALE UN NOMBRE A TUS ARCHIVO...)
col_perf <- trimws(unlist(strsplit(col_perf_input, ",")))
prefijo <- readline("\n-> Prefijo para archivos de salida: ")
}
{
cat("\n INDICA EL NUMERO DE ITERACIONES PARA LE BOOSTRAP")
iter_r <- as.numeric(readline("-> ¿Iteraciones Bootstrap? (200 sugerido): "))
if(is.na(iter_r)) iter_r <- 200
}
# 2. OPCIÓN DE DISPERSIÓN PARA TABLA RESUMEN
{
  cat("\n COMPLETA LAS OPCIONES DE DESCRIPCION PARA LA TABLA DE RESUMEN")
cat("\n[!] Elige la medida de dispersión para la tabla resumen:")
cat("\n    1. SE (Error Estándar) | 2. SD (Desviación) | 3. VAR (Varianza)")
medida_opt <- readline("Selección: ")
sufijo <- switch(medida_opt, "1" = "se", "2" = "sd", "3" = "var", "sd")
disp_func <- switch(medida_opt, 
                    "1" = function(x) sd(x, na.rm=T)/sqrt(sum(!is.na(x))), 
                    "2" = function(x) sd(x, na.rm=T), 
                    "3" = function(x) var(x, na.rm=T), sd)
}
# 3. CONFIGURACIÓN DE GRÁFICOS Y GUARDADO
{
cat("\n CONFIGUREMOS LA SALIDA GRAFICA")
cat("\n[PASO 2]: Personalización de gráficos:")
marcar_topt <- toupper(readline("-> ¿Marcar T-Óptima (Vertical)? (S/N): ")) == "S"
}
marcar_pmax <- toupper(readline("-> ¿Marcar P-Máximo (Horizontal)? (S/N): ")) == "S"
{
cat("\n¿Qué rango de Breadth quieres sombrear?")
cat("\n  1. TB80 | 2. TB50 | 3. Ninguno")
breadth_opt <- readline("Selección: ")
}
{
cat("\n[PASO 3]: Opciones de guardado:")
g_plots    <- toupper(readline("-> ¿Guardar gráficos (PNG)? (S/N): ")) == "S"
}
g_excel    <- toupper(readline("-> ¿Guardar tabla resumen (Excel)? (S/N): ")) == "S"
g_boot_raw <- toupper(readline("-> ¿Guardar bootstrap crudo (Excel)? (S/N): ")) == "S"

# 4. FUNCIONES DE MODELADO (Briere-1)
{
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
  
  # Q10 (Ratio entre Topt y Topt-5)
  perf_opt <- briere_model(Topt, p["Tmin"], p["Tmax"], p["a"])
  perf_sub <- briere_model(Topt - 5, p["Tmin"], p["Tmax"], p["a"])
  q10_val  <- if(!is.na(perf_sub) && perf_sub > 0) perf_opt / perf_sub else NA
  
  # AUC via Integración
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

# 5. PROCESAMIENTO DE DATOS
df <- df_raw %>% rename(TEMP = all_of(col_temp), sp_num = all_of(col_sp)) %>% mutate(TEMP = as.numeric(TEMP))
especies <- unique(df$sp_num)
p_names <- c("Q10", "Cm", "Tth", "d", "Topt", "Pmax", "P50", "T50_min", "T50_max", "P80", "T80_min", "T80_max", "TB_80", "TB_50", "Tmin_ajust", "AUC")

resultados_list <- list(); t_resumen <- list(); t_boot_crudo <- list()

cat("\n[!] Analizando y calculando métricas...\n")

for (esp in especies) {
  for (v in col_perf) {
    temp_data <- df %>% filter(sp_num == esp) %>% select(TEMP, Perf = all_of(v)) %>% drop_na()
    if(nrow(temp_data) < 7) next
    
    cat(paste("    > Procesando:", esp, "[", v, "]... "))
    res_boot <- try(boot(data = temp_data, statistic = get_all_params, R = iter_r), silent = TRUE)
    
    if(!inherits(res_boot, "try-error")) {
      res_df <- as.data.frame(res_boot$t) %>% drop_na()
      colnames(res_df) <- p_names
      
      f_mean <- colMeans(res_df)
      f_disp <- sapply(res_df, disp_func)
      
      # Tabla Resumen
      fila_res <- data.frame(Especie = esp, Variable = v)
      for(n in p_names) {
        fila_res[[paste0(n, "_mean")]] <- f_mean[n]
        fila_res[[paste0(n, "_", sufijo)]] <- f_disp[n]
      }
      t_resumen[[paste(esp, v)]] <- fila_res
      
      # Tabla Bootstrap Crudo (Incluye columna de Especie y Variable)
      if(g_boot_raw) {
        t_boot_crudo[[paste(esp, v)]] <- res_df %>% mutate(Especie = esp, Variable = v)
      }
      
      resultados_list[[paste(esp, v)]] <- list(boot = res_df, data = temp_data, esp = esp, v = v, f = f_mean)
      cat("OK.\n")
    } else { cat("Error.\n") }
  }
}
}

# 6. GENERACIÓN DE GRÁFICOS (AJUSTE VISUAL ABSOLUTO)
{
cat("\n[!] Generando figuras finales...... ESPERAR HASTA QUE DESAPAREZCA EL STOP DE LA CONSOLA\n")

for (item in resultados_list) {
  f <- item$f
  
  # 1. Generamos la curva roja con alta resolución basada en los promedios
  curva_roja <- data.frame(T = seq(f["Tmin_ajust"], f["Tth"], length.out = 2000)) %>% 
    mutate(P = briere_model(T, f["Tmin_ajust"], f["Tth"], f["Cm"]))
  
  # 2. Extraemos valores exactos de LA CURVA ROJA dibujada (no de la tabla)
  p_max_rojo <- max(curva_roja$P, na.rm = TRUE)
  t_opt_rojo <- curva_roja$T[which.max(curva_roja$P)]
  
  # Límites de Breadth basados en la curva roja
  target_p <- if(breadth_opt == "1") p_max_rojo * 0.8 else p_max_rojo * 0.5
  idx_breadth <- which(curva_roja$P >= target_p)
  
  y_lim <- max(c(p_max_rojo, max(item$data$Perf)), na.rm = TRUE) * 1.15
  
  g <- ggplot()
  
  # CAPA: Sombreado Breadth (Ajuste absoluto)
  if(breadth_opt %in% c("1", "2") && length(idx_breadth) > 0) {
    t_min_b <- curva_roja$T[min(idx_breadth)]
    t_max_b <- curva_roja$T[max(idx_breadth)]
    g <- g + geom_rect(aes(xmin = t_min_b, xmax = t_max_b, ymin = 0, ymax = target_p), 
                       fill = ifelse(breadth_opt=="1", "forestgreen", "orange"), alpha = 0.2)
  }
  
  # CAPA: Líneas de Bootstrap (Gris)
  g <- g + geom_line(data = item$boot %>% sample_n(min(nrow(.), 40)) %>% mutate(id = row_number()) %>% group_by(id) %>% 
                       do(data.frame(T_G = seq(.[["Tmin_ajust"]], .[["Tth"]], length.out = 100), 
                                     P_G = briere_model(seq(.[["Tmin_ajust"]], .[["Tth"]], length.out = 100), .[["Tmin_ajust"]], .[["Tth"]], .[["Cm"]]))),
                     aes(x = T_G, y = P_G, group = id), color = "grey92", alpha = 0.4)
  
  # CAPA: Curva Roja Principal y Puntos de Datos
  g <- g + geom_line(data = curva_roja, aes(x = T, y = P), color = "firebrick", linewidth = 1.3) +
    geom_point(data = item$data, aes(x = TEMP, y = Perf), alpha = 0.7, size = 3)
  
  # CAPA: Marcadores dinámicos (Referenciados a la curva roja)
  if(marcar_topt) g <- g + geom_vline(xintercept = t_opt_rojo, linetype = "dashed", color = "darkblue", alpha = 0.8)
  if(marcar_pmax) g <- g + geom_hline(yintercept = p_max_rojo, linetype = "dotted", color = "darkred", alpha = 0.8)
  
  g <- g + scale_y_continuous(limits = c(0, y_lim), expand = c(0,0)) +
    scale_x_continuous(limits = c(min(0, f["Tmin_ajust"]-2), f["Tth"]+3), expand = c(0,0)) +
    theme_classic(base_size = 14) + 
    labs(title = paste("ID:", item$esp), subtitle = paste("Variable:", item$v), 
         x = "Temperatura (°C)", y = item$v)
  
  if(g_plots) ggsave(paste0(prefijo, "_", item$esp, "_", item$v, ".png"), plot = g, width = 8, height = 6)
}
}

# 7. EXPORTACIÓN FINAL
{
  cat("\n[!] Generando TABLAS DE RESUMEN + BOOSTRAPING TOTAL\n")
if(g_excel && length(t_resumen) > 0) {
  write.xlsx(bind_rows(t_resumen), paste0(prefijo, "_Resumen_Final.xlsx"))
}
if(g_boot_raw && length(t_boot_crudo) > 0) {
  write.xlsx(bind_rows(t_boot_crudo), paste0(prefijo, "_Bootstrap_Completo.xlsx"))
}

cat("\n\n--- PROCESO COMPLETADO ---")
}
