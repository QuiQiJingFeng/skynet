local constants = {}

constants["LIMIT_VERSION"] = "1.0.0"

constants["MAX_USER_ID"] = 4967000

constants["ERROR_CODE"] = {
	ERROR_LOGIN_TYPE = "ERROR_LOGIN_TYPE",
	OVER_MAX_ID = "OVER_MAX_ID",
	HTTP_ERROR = "HTTP_ERROR",
	LOGIN_CHECK_ERROR = "LOGIN_CHECK_ERROR",
}

constants["PRODUCTS_TYPE"] = {
    [1] = "appstore",
    [2] = "google"
}

return constants