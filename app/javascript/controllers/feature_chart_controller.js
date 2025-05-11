import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

export default class extends Controller {
  static values = { data: Object }
  
  connect() {
    if (!this.dataValue) return

    const featureImportance = this.dataValue
    
    // Преобразуем данные в формат для круговой диаграммы
    const labels = []
    const values = []
    const backgroundColors = [
      'rgba(255, 99, 132, 0.7)',
      'rgba(54, 162, 235, 0.7)',
      'rgba(255, 206, 86, 0.7)',
      'rgba(75, 192, 192, 0.7)'
    ]
    
    // Определяем названия факторов
    const featureLabels = {
      "0": "CPU",
      "1": "Память",
      "2": "Запросы"
    }
    
    Object.entries(featureImportance).forEach(([key, value]) => {
      labels.push(featureLabels[key] || `Фактор ${key}`)
      values.push(value)
    })
    
    // Создаем график
    const ctx = this.element.getContext('2d')
    
    new Chart(ctx, {
      type: 'doughnut',
      data: {
        labels: labels,
        datasets: [{
          data: values,
          backgroundColor: backgroundColors,
          hoverOffset: 4
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'top',
          },
          title: {
            display: true,
            text: 'Влияние факторов на производительность'
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                const label = context.label || '';
                const value = context.formattedValue;
                const percentage = Math.round(parseFloat(value) * 100);
                return `${label}: ${percentage}%`;
              }
            }
          }
        }
      }
    })
  }
}