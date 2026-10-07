local Exec = require("./Shared/Exec")

local ProjectFile = "example.project.json"

print(`serving {ProjectFile}`)
print("connect with the Rojo plugin in Studio, then press Ctrl+C here to stop")

Exec.Attempt("rojo", { "serve", ProjectFile })
