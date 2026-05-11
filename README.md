# TPC-analysis V13
Este repositorio contiene un script de R diseñado para el análisis automatizado de Curvas de Rendimiento Térmico (TPCs) utilizando el modelo no lineal de Briere. Basado tambien en el script publicado por Rezende y colaboradores en el 2009. La herramienta está optimizada para investigadores en biología y ecología que necesitan procesar múltiples especies y variables de rendimiento de manera simultánea y reproducible.

🚀 Características Principales
Modelado Robusto: Implementación del modelo de Briere para estimar parámetros térmicos fundamentales.

Análisis Bootstrap: Genera intervalos de confianza y estimaciones precisas mediante remuestreo (bootstrapping).

Sincronización Visual: Escalado automático de ejes (X e Y) basado en las estimaciones del bootstrap, permitiendo la comparación visual directa entre diferentes especies o tratamientos sin distorsión de escala.

Cálculo de AUC: Integración numérica para obtener el Área Bajo la Curva (AUC), representando el rendimiento total acumulado de la especie (Bozinovich et al., ).

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
