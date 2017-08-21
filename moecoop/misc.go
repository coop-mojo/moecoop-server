package moecoop

import (
	middleware "github.com/go-openapi/runtime/middleware"

	"github.com/coop-mojo/moecoop-server/restapi/operations/その他"
)

func Version(params その他.GetVersionParams) middleware.Responder {
	ver := "2.0"
	payload := その他.GetVersionOKBody{
		Version: &ver,
	}

	return その他.NewGetVersionOK().WithPayload(payload)
}
