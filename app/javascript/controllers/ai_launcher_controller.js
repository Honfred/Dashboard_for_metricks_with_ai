import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["metric", "analysisType"]

  connect() {
    console.log("AI Launcher controller connected")
  }

  launch() {
    const metricId = this.metricTarget.value
    const analysisType = this.analysisTypeTarget.value
    
    if (!metricId) {
      alert('Пожалуйста, выберите метрику')
      return
    }
    
    if (!analysisType) {
      alert('Пожалуйста, выберите тип анализа')
      return
    }
    
    // Перенаправляем на страницу создания нового анализа с выбранной метрикой
    window.location.href = `/metrics/${metricId}/ai_analyses/new?analysis_type=${analysisType}`
  }
}