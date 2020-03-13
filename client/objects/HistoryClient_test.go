package objects

import "testing"

func TestGetConnect(t *testing.T) {
	props := ClientProperties{
		Host: "localhost",
	}
	if props.Host != "localhost" {
		t.Error("needs to be valid host", props.Host)
	} else {
		t.Log(props.Host)
		//props.getConnection()

	}
}
