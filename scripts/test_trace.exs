defmodule TraceTest do
  def run do
    # Ensure Jaeger export is running
    :timer.sleep(1000)

    user_id = Uniq.UUID.uuid7()
    org_id = Uniq.UUID.uuid7()
    
    command = %Nexus.Identity.Commands.RegisterUser{
      user_id: user_id,
      org_id: org_id,
      email: "automated-trace-1@nexus.com",
      name: "Automated Trace",
      role: "admin",
      cose_key: "mock",
      credential_id: "mock"
    }

    require OpenTelemetry.Tracer

    IO.puts("Dispatching command...")
    OpenTelemetry.Tracer.with_span "Test.AutomatedTrace" do
      ctx = OpenTelemetry.Ctx.get_current()
      IO.inspect(ctx, label: "Current OTel Context")
      
      case Nexus.App.dispatch(command) do
        :ok -> IO.puts("Command dispatched successfully.")
        err -> IO.inspect(err, label: "Dispatch Error")
      end
    end

    # Give Jaeger time to export
    :timer.sleep(3000)
    IO.puts("Test complete for user_id: #{user_id}")
  end
end

TraceTest.run()
