pin "sample_engine/application"
pin_all_from File.expand_path("../app/javascript/sample_engine/controllers", __dir__),
             under: "controllers/sample_engine", to: "sample_engine/controllers"
