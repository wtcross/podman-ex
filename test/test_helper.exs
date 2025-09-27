Application.ensure_all_started(:bypass)
Code.require_file("support/integration_case.exs", __DIR__)
ExUnit.start()
