import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

export default class extends Controller {
  static values = { data: Object }
  
  connect() {
    if (!this.dataValue) return
    
    const chartData = this.dataValue.chart_data
    if (!chartData) return

    // Получаем текущие и прогнозные данные
    const currentData = chartData.current
    const predictionData = chartData.prediction
    
    if (!currentData || !predictionData) return
    
    // Форматируем метки времени
    const formatTimestamp = (ts) => {
      const date = new Date(ts * 1000)
      return date.toLocaleString('ru', { hour: '2-digit', minute: '2-digit', day: '2-digit', month: '2-digit' })
    }
    
    const currentLabels = currentData.timestamps.map(formatTimestamp)
    const predictionLabels = predictionData.timestamps.map(formatTimestamp)
    
    // Объединяем метки и данные
    const labels = [...currentLabels, ...predictionLabels]
    
    // Создаем массивы данных для графика
    const currentValues = [...currentData.values, ...Array(predictionData.values.length).fill(null)]
    const predictionValues = [...Array(currentData.values.length).fill(null), ...predictionData.values]
    
    // Создаем график
    const ctx = this.element.getContext('2d')
    
    new Chart(ctx, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [
          {
            label: 'Текущие значения',
            data: currentValues,
            borderColor: 'rgba(75, 192, 192, 1)',
            backgroundColor: 'rgba(75, 192, 192, 0.2)',
            tension: 0.1,
            pointRadius: 3
          },
          {
            label: 'Прогноз',
            data: predictionValues,
            borderColor: 'rgba(255, 205, 86, 1)',
            backgroundColor: 'rgba(255, 205, 86, 0.2)',
            tension: 0.1,
            pointRadius: 3,
            borderDash: [5, 5]
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          x: {
            grid: {
              display: false
            }
          }
        },
        plugins: {
          tooltip: {
            mode: 'index',
            intersect: false
          },
          legend: {
            position: 'top',
          },
          title: {
            display: true,
            text: 'Прогноз поведения метрики'
          }
        }
      }
    })
  }
}