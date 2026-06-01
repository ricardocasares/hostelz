const KEY = "hostelz_token";

export function readToken() {
  return globalThis.localStorage?.getItem(KEY) ?? "";
}

export function writeToken(token) {
  globalThis.localStorage?.setItem(KEY, token);
  return undefined;
}

export function clearToken() {
  globalThis.localStorage?.removeItem(KEY);
  return undefined;
}

export function origin() {
  return globalThis.location?.origin ?? "";
}
