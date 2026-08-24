// oxmysql can surface TINYINT flags as numbers, numeric strings or booleans
// depending on its connection/parser configuration. Normalize at the UI
// boundary so every admin indicator and switch reads the same value.
export function databaseBoolean(value) {
  return value === true || value === 1 || value === '1'
}

export function requestTypePassengerMode(requestType) {
  return requestType?.passenger_mode || (databaseBoolean(requestType?.passenger_count) ? 'required' : 'disabled')
}

export function requestTypeNoteMode(requestType) {
  return requestType?.note_mode || (databaseBoolean(requestType?.description_enabled) ? 'optional' : 'disabled')
}
