import { Controller } from "@hotwired/stimulus"
import Chart from 'chart.js/auto'

export default class extends Controller {
  static values = { data: Array }

  connect() {
    this.initChart()
  }

  initChart() {
    if (!this.dataValue || !this.element) return
    
    const predictionsData = this.dataValue
    
    // Создаем гистограмму предсказанных значений
    new Chart(this.element, {
      type: 'bar',
      data: {
        labels: Array.from({ length: predictionsData.length }, (_, i) => i + 1),
        datasets: [{
          label: 'Прогнозируемые значения',
          data: predictionsData,
          backgroundColor: 'rgba(75, 192, 192, 0.6)',
          borderColor: 'rgba(75, 192, 192, 1)',
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          title: {
            display: true,
            text: 'Распределение предсказанных значений'
          },
          legend: {
            display: false
          }
        },
        scales: {
          x: {
            title: {
              display: true,
              text: 'Порядковый номер прогноза'
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