import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

export default class extends Controller {
  static values = { data: Object }
  
  connect() {
    if (!this.dataValue) return
    
    const predictions = this.dataValue
    if (!Array.isArray(predictions) || predictions.length === 0) return
    
    // Создаем метки для оси X (просто номера точек)
    const labels = Array.from({length: predictions.length}, (_, i) => `#${i+1}`)
    
    // Рассчитываем среднее значение для опорной линии
    const average = predictions.reduce((a, b) => a + b, 0) / predictions.length
    
    // Создаем график
    const ctx = this.element.getContext('2d')
    
    new Chart(ctx, {
      type: 'bar',
      data: {
        labels: labels,
        datasets: [{
          label: 'Предсказанные значения',
          data: predictions,
          backgroundColor: predictions.map(value => 
            value > average * 1.2 ? 'rgba(255, 99, 132, 0.6)' : 
            value < average * 0.8 ? 'rgba(54, 162, 235, 0.6)' : 
            'rgba(75, 192, 192, 0.6)'
          ),
          borderColor: 'rgba(0, 0, 0, 0.1)',
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
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
            text: 'Предсказанные значения производительности'
          },
          annotation: {
            annotations: {
              line1: {
                type: 'line',
                yMin: average,
                yMax: average,
                borderColor: 'rgba(255, 99, 132, 1)',
                borderWidth: 2,
                borderDash: [5, 5],
                label: {
                  content: 'Среднее',
                  enabled: true,
                  position: 'end'
                }
              }
            }
          }
        },
        scales: {
          x: {
            grid: {
              display: false
            }
          },
          y: {
            beginAtZero: true
          }
        }
      }
    })
  }
}