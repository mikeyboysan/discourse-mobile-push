import { ajax } from "discourse/lib/ajax";

const BASE_PATH = "/admin/mobile-push";

export function fetchStatus() {
  return ajax(`${BASE_PATH}/status.json`);
}

export function fetchDevices({ username, page }) {
  const data = { page };
  if (username) {
    data.username = username;
  }
  return ajax(`${BASE_PATH}/devices.json`, { data });
}

export function sendTestNotification(deviceId) {
  return ajax(`${BASE_PATH}/devices/${deviceId}/test.json`, { type: "POST" });
}

export function removeDevice(deviceId) {
  return ajax(`${BASE_PATH}/devices/${deviceId}.json`, { type: "DELETE" });
}
