## HTTPRequest_Authorized.gd - HTTPRequest con Bearer token automático
## Extiende HTTPRequest para auto-agregar Authorization header
extends HTTPRequest

class_name HTTPRequest_Authorized

# ============================================================================
# OVERRIDE: request()
# ============================================================================

## Realiza un request HTTP pero agrega automáticamente el Bearer token
## Si el token no existe, realiza request sin autorización
func request_authorized(
	url: String,
	custom_headers: PackedStringArray = PackedStringArray(),
	method: HTTPClient.Method = HTTPClient.METHOD_GET,
	request_data: String = ""
) -> int:
	
	# Agregar header de autorización
	var headers = custom_headers.duplicate()
	var session_mgr = get_tree().root.get_node("SessionManager")
	var access_token = session_mgr.get_access_token()
	
	if not access_token.is_empty():
		headers = _add_or_replace_header(headers, "Authorization", "Bearer %s" % access_token)
	
	# Realizar request con headers modificados
	return request(url, headers, method, request_data)

## Realiza un request GET con autorización
func get_authorized(url: String) -> int:
	return request_authorized(url, PackedStringArray(), HTTPClient.METHOD_GET)

## Realiza un request POST con autorización y JSON
func post_json_authorized(url: String, data: Dictionary) -> int:
	var headers = PackedStringArray(["Content-Type: application/json"])
	var body = JSON.stringify(data)
	return request_authorized(url, headers, HTTPClient.METHOD_POST, body)

## Realiza un request PUT con autorización y JSON
func put_json_authorized(url: String, data: Dictionary) -> int:
	var headers = PackedStringArray(["Content-Type: application/json"])
	var body = JSON.stringify(data)
	return request_authorized(url, headers, HTTPClient.METHOD_PUT, body)

## Realiza un request DELETE con autorización
func delete_authorized(url: String) -> int:
	return request_authorized(url, PackedStringArray(), HTTPClient.METHOD_DELETE)

# ============================================================================
# PRIVADAS
# ============================================================================

func _add_or_replace_header(headers: PackedStringArray, header_name: String, header_value: String) -> PackedStringArray:
	"""Agrega o reemplaza un header en el array"""
	var result = headers.duplicate()
	var found = false
	
	# Buscar si el header ya existe
	for i in range(result.size()):
		if result[i].begins_with(header_name + ":"):
			result[i] = "%s: %s" % [header_name, header_value]
			found = true
			break
	
	# Si no existe, agregarlo
	if not found:
		result.append("%s: %s" % [header_name, header_value])
	
	return result
