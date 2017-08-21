
APP=fukurod
SRC=cmd/fukurod-server/main.go
SWAGGER=common/api/swagger.yml


all: $(APP)

$(SWAGGER):
	git submodule init
	git submodule update

$(SRC): $(SWAGGER)
	swagger generate server -f $^ -A $(APP)

$(APP): $(SRC)
	go get -u -f ./...
	go build -o $@ $^

clean:
	@rm -rf $(APP)
