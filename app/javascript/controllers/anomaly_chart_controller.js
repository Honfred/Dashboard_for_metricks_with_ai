import { Controller } from "@hotwired/stimulus"
import Chart from 'chart.js/auto'

export default class extends Controller {
  static values = { data: Object }

  connect() {
    this.initChart()
  }

  initChart() {
    if (!this.dataValue || !this.element) return
    
    const data = this.dataValue
    
    // Проверяем формат данных и извлекаем события и текущие значения
    let events = []
    let timestamps = []
    let values = []
    let anomalyPoints = []
    let normalPoints = []
    
    if (data.events && data.events.length > 0) {
      // Сортируем события по временной метке
      const sortedEvents = [...data.events].sort((a, b) => a.timestamp - b.timestamp)
      
      // Извлекаем данные для графика
      timestamps = sortedEvents.map(e => new Date(e.timestamp * 1000))
      values = sortedEvents.map(e => e.value)
      
      // Разделяем точки на аномальные и нормальные
      sortedEvents.forEach((e, i) => {
        if (e.type === 'anomaly') {
          anomalyPoints.push({x: timestamps[i], y: values[i]})
        }
      })
    }
    
    // Если есть текущие данные, добавляем их
    if (data.current_data) {
      const currentTimestamps = data.current_data.timestamps.map(t => new Date(t * 1000))
      const currentValues = data.current_data.values
      
      timestamps = [...currentTimestamps, ...timestamps]
      values = [...currentValues, ...values]
      
      // Добавляем нормальные точки
      currentTimestamps.forEach((t, i) => {
        normalPoints.push({x: t, y: currentValues[i]})
      })
    }
    
    // Создаем график
    new Chart(this.element, {
      type: 'line',
      data: {
        datasets: [
          {
            label: 'Значения метрики',
            data: normalPoints,
            fill: false,
            borderColor: 'rgba(54, 162, 235, 1)',
            tension: 0.1,
            pointRadius: 2
          },
          {
            label: 'Аномалии',
            data: anomalyPoints,
            fill: false,
            showLine: false,
            borderColor: 'rgba(255, 99, 132, 1)',
            backgroundColor: 'rgba(255, 99, 132, 1)',
            pointRadius: 6,
            pointHoverRadius: 8
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          title: {
            display: true,
            text: 'Обнаружение аномалий'
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                const dataset = context.dataset
                const index = context.dataIndex
                const point = dataset.data[index]
                return `${dataset.label}: ${point.y}`
              }
            }
          }
        },
        scales: {
          x: {
            type: 'time',
            time: {
              unit: 'hour',
              displayFormats: {
                hour: 'dd.MM HH:mm'
              },
              tooltipFormat: 'dd.MM.yyyy HH:mm'
            },
            title: {
              display: true,
              text: 'Дата и время'
            }
          },
          y: {
            title: {
              display: true,
              text: 'Значение'
            },
            beginAtZero: false
          }
        }
      }
    })
  }
  
  disconnect() {
    // Очистка ресурсов при отключении контроллера
  }
}