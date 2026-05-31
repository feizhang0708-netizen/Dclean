import Foundation

func getThermalState() -> String {
    switch ProcessInfo.processInfo.thermalState {
    case .nominal:  return "正常"
    case .fair:     return "轻度"
    case .serious:  return "严重"
    case .critical: return "危险"
    @unknown default:return "未知"
    }
}

func getTempJSON() -> String {
    let state = getThermalState()
    return "{\"thermalState\":\"\(state)\"}"
}
