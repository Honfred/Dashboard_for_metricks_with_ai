import { Controller } from "@hotwired/stimulus"
import Chart from 'chart.js/auto'

export default class extends Controller {
  static values = { data: Object }

  connect() {
    this.initChart()
  }

  initChart() {
    if (!this.dataValue || !this.element) return
    
    const featureData = this.dataValue
    
    // Подготовка данных для круговой диаграммы
    const labels = []
    const values = []
    const backgroundColors = [
      'rgba(255, 99, 132, 0.7)',
      'rgba(54, 162, 235, 0.7)',
      'rgba(255, 206, 86, 0.7)',
      'rgba(75, 192, 192, 0.7)',
      'rgba(153, 102, 255, 0.7)'
    ]
    
    // Преобразование ключей в более читаемые названия
    // и извлечение значений
    Object.entries(featureData).forEach(([key, value], index) => {
      let label = key
      
      // Преобразуем ключи в более понятные названия
      switch(key) {
        case '0':
          label = 'CPU'
          break
        case '1':
          label = 'Память'
          break
        case '2':
          label = 'Запросы'
          break
        case '3':
          label = 'Пользователи'
          break
        default:
          label = `Фактор ${parseInt(key) + 1}`
      }
      
      labels.push(label)
      values.push(value * 100) // Преобразуем в проценты для лучшего отображения
    })
    
    // Создаем круговую диаграмму
    new Chart(this.element, {
      type: 'pie',
      data: {
        labels: labels,
        datasets: [{
          data: values,
          backgroundColor: backgroundColors,
          borderColor: backgroundColors.map(color => color.replace('0.7', '1')),
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        plugins: {
          legend: {
            position: 'right',
          },
          title: {
            display: true,
            text: 'Влияние факторов на производительность (%)'
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                const label = context.label || '';
                const value = context.parsed || 0;
                return `${label}: ${value.toFixed(1)}%`;
              }
            }
          }
        }
      }
    })
  }
  
  disconnect() {
    // Очистка ресурсов при отключении контроллера
  }
}