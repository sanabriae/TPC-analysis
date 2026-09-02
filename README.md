NUEVA VERSION 15
**TPC-Analyzer V15** es una herramienta computacional avanzada desarrollada en R para el modelado, integración de métricas fisiológicas y visualización comparativa de **Curvas de Rendimiento Térmico (TPCs)**. 

Esta versión aborda rigurosamente el ajuste de modelos no lineales asimétricos (**Briere-1**) combinados con **Bootstrap No Paramétrico**, proporcionando estimaciones tanto paramétricas (Media, SE/SD) como no paramétricas (Mediana, IC95%) para responder a los estándares de publicación en ecofisiología.

---

## 🌟 Novedades y Mejoras en la V15

1. **Ajuste de Caída Térmica Superior (Evaluación Punto por Punto):**
   A diferencia de las versiones anteriores que promediaban directamente los parámetros del bootstrap (lo que generaba una "cola artificial" de movilidad en zonas de alta temperatura), la V14.2 evalúa la mediana de las curvas construidas punto por punto (*Pointwise Median Evaluation*). Esto asegura que la curva caiga exactamente a $0$ en los límites térmicos donde los organismos no muestran movilidad funcional.

2. **Banda de Confianza del 95% (IC95%):**
   Sustituye las líneas individuales del bootstrap por una banda sombreada continua basada en los percentiles $2.5\%$ y $97.5\%$, proporcionando una representación clara y elegante de la incertidumbre estadística.

3. **Reporte Consolidado en Excel (Paramétrico + No Paramétrico):**
   La tabla resumen exportada incluye en un único archivo la aproximación tradicional (`Mean` ± `SE`/`SD`/`VAR`) junto con la aproximación robusta (`Median` y `IC95%` inferior/superior) para los 16 parámetros calculados.

4. **Integración Numérica de AUC (Area Under Curve):**
   Calcula la capacidad metabólica total mediante la integración del área bajo el modelo de Briere en cada iteración del bootstrap, permitiendo comparar el "presupuesto de rendimiento total" entre especies generalistas y especialistas.

---

## 📊 Métricas Calculadas (16 Parámetros)

El script procesa automáticamente múltiples especies y variables de rendimiento (ej. fuerza de mordida, velocidad de carrera, tasa metabólica), extrayendo:

| Parámetro | Código | Descripción |
| :--- | :--- | :--- |
| **Q10** | `Q10` | Sensibilidad térmica estimada en el rango ascendente ($T_{opt} - 5^\circ\text{C}$). |
| **Constante a** | `Cm` | Parámetro de escala del modelo de Briere. |
| **Umbral Térmico** | `Tth` | Límite térmico superior estimado ($CT_{max}$). |
| **Asimetría** | `d` | Diferencia térmica entre $T_{opt}$ y $T_{max}$ ($T_{th} - T_{opt}$). |
| **Temperatura Óptima** | `Topt` | Temperatura donde se alcanza el rendimiento máximo ($P_{max}$). |
| **Rendimiento Máximo** | `Pmax` | Valor máximo estimado de rendimiento fisiológico. |
| **Rendimiento al 50%** | `P50` | $50\%$ del valor de $P_{max}$. |
| **Límite Inferior TB50** | `T50_min` | Temperatura mínima para alcanzar el $50\%$ de rendimiento. |
| **Límite Superior TB50** | `T50_max` | Temperatura máxima para alcanzar el $50\%$ de rendimiento. |
| **Rendimiento al 80%** | `P80` | $80\%$ del valor de $P_{max}$ (umbral de alto desempeño). |
| **Límite Inferior TB80** | `T80_min` | Temperatura mínima para alcanzar el $80\%$ de rendimiento. |
| **Límite Superior TB80** | `T80_max` | Temperatura máxima para alcanzar el $80\%$ de rendimiento. |
| **Ancho Térmico 80%** | `TB_80` | Amplitud térmica del rango de óptimo desempeño ($T80_{max} - T80_{min}$). |
| **Ancho Térmico 50%** | `TB_50` | Amplitud térmica del rango funcional ($T50_{max} - T50_{min}$). |
| **T-Mínima Ajustada** | `Tmin_ajust` | Límite crítico inferior estimado ($CT_{min}$). |
| **Área Bajo la Curva** | `AUC` | Rendimiento integral acumulado en todo el rango térmico. |

---

## 🛠️ Requisitos e Instalación

El script utiliza el gestor `pacman` para verificar e instalar automáticamente todas las librerías necesarias:

```R
if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse, minpack.lm, boot, readxl, openxlsx)


# TPC-analysis V13 
[[![DOI](https://zenodo.org/badge/1235222605.svg)](https://doi.org/10.5281/zenodo.20122463)
](https://doi.org/10.5281/zenodo.20122463)

Este repositorio contiene un script de R diseñado para el análisis automatizado de Curvas de Rendimiento Térmico (TPCs) utilizando el modelo no lineal de Briere et al. (1999). Basado tambien en el script publicado por Rezende y colaboradores en el 2019. La herramienta está optimizada para investigadores en biología y ecología que necesitan procesar múltiples especies y variables de rendimiento de manera simultánea y reproducible.

🚀 Características Principales
Modelado Robusto: Implementación del modelo de Briere para estimar parámetros térmicos fundamentales.

Análisis Bootstrap: Genera intervalos de confianza y estimaciones precisas mediante remuestreo (bootstrapping).

Sincronización Visual: Escalado automático de ejes (X e Y) basado en las estimaciones del bootstrap, permitiendo la comparación visual directa entre diferentes especies o tratamientos sin distorsión de escala.

Cálculo de AUC: Integración numérica para obtener el Área Bajo la Curva (AUC), representando el rendimiento total acumulado de la especie (Cortes et al., 2016).

Exportación Integral: Generación automática de:

Gráficos de alta resolución (PNG) con la curva media y las iteraciones del bootstrap.

Tablas resumen con estadísticas descriptivas (Media, SE, SD o VAR).

Datasets crudos del bootstrap para análisis secundarios.

📊 Parámetros Calculados
El script extrae automáticamente 16 parámetros críticos, incluyendo:

Topt: Temperatura óptima.

Pmax: Rendimiento máximo.

Tth (Tmax): Límite térmico superior estimado.

Tmin: Límite térmico inferior estimado.

B80 / B50: Ancho del nicho térmico al 80% y 50% del rendimiento.

AUC: Rendimiento integral en todo el rango térmico.

🛠️ Requisitos
El script gestiona automáticamente sus dependencias mediante el paquete pacman. Utiliza principalmente:

tidyverse (Manipulación de datos y visualización)

minpack.lm (Ajuste de modelos no lineales)

boot (Simulaciones de remuestreo)

openxlsx (Exportación a Excel)

📋 Uso Rápido
Prepara tu archivo de datos en Excel con columnas para Temperatura, Especie y las Variables de Rendimiento.

Ejecuta el script en RStudio.

Sigue las instrucciones en la consola para seleccionar el archivo y configurar las columnas.

Los resultados se guardarán automáticamente en una carpeta organizada por fecha y hora.

Bibliografia
Rezende, E. L., & Bozinovic, F. (2019). Thermal performance across levels of biological organization. Philosophical Transactions of the Royal Society B: Biological Sciences, 374(1778).
Briere, J. F., Pracros, P., the Luycker, A. Y., & Porphyre, V. (1999). A novel rate model of temperature-dependent development for arthropods. Environmental Entomology, 28(1), 22-29.
Cortes, P. A., Puschel, H., Acuña, P., Bartheld, J. L., & Bozinovic, F. (2016). Thermal ecological physiology of native and invasive frog species: do invaders perform better?. Conservation Physiology, 4(1), cow056.
