defmodule NexusWeb.KYBEmail do
  @moduledoc """
  Transactional emails for KYB lifecycle events.
  """
  import Swoosh.Email
  import NexusWeb.Brand

  alias NexusWeb.Mailer

  def send_kyb_approved(name, email) do
    new()
    |> from({brand_name(), "noreply@nexus.finance"})
    |> to({name, email})
    |> subject("Your #{brand_name()} Account Has Been Activated")
    |> text_body("""
    #{name},

    Your KYB review has been completed and your #{brand_name()} account is now active.

    You may now log in and access the full platform.

    — #{brand_name()} Operations
    """)
    |> html_body("""
    <!DOCTYPE html>
    <html>
    <body style="background:#010101;color:#fff;font-family:ui-monospace,monospace;padding:40px 20px;margin:0;">
      <div style="max-width:560px;margin:0 auto;">
        <div style="border-bottom:1px solid #ffffff10;padding-bottom:24px;margin-bottom:32px;">
          <span style="font-size:11px;letter-spacing:0.3em;text-transform:uppercase;color:#34d399;font-weight:700;">#{brand_name_upper()} · INSTITUTIONAL TREASURY</span>
        </div>
        <h1 style="font-size:22px;font-weight:700;margin:0 0 8px;">Account Activated</h1>
        <p style="font-size:12px;color:#71717a;margin:0 0 32px;letter-spacing:0.1em;text-transform:uppercase;">KYB Review Complete</p>
        <p style="font-size:13px;color:#d4d4d8;line-height:1.6;">#{name},</p>
        <p style="font-size:13px;color:#d4d4d8;line-height:1.6;">
          Your KYB review has been completed and your #{brand_name()} account is now fully activated.
          You may log in and access the platform at any time.
        </p>
        <div style="margin:40px 0;border-top:1px solid #ffffff08;border-bottom:1px solid #ffffff08;padding:24px 0;">
          <p style="font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:0.25em;color:#52525b;margin:0 0 4px;">Status</p>
          <p style="font-size:13px;color:#34d399;font-weight:700;margin:0;">ACTIVE · CLEARED</p>
        </div>
        <p style="font-size:11px;color:#3f3f46;margin-top:48px;letter-spacing:0.1em;">#{brand_name_upper()} OPERATIONS · AUTOMATED NOTIFICATION</p>
      </div>
    </body>
    </html>
    """)
    |> Mailer.deliver()
  end

  def send_access_rejected(name, email, reason) do
    new()
    |> from({brand_name(), "noreply@nexus.finance"})
    |> to({name, email})
    |> subject("Update on Your #{brand_name()} Access Request")
    |> text_body("""
    #{name},

    Thank you for your interest in #{brand_name()}. After careful review, we are unable
    to approve your access request at this time.

    #{if reason, do: "Reason: #{reason}\n\n", else: ""}If you believe this decision was made in error or your circumstances have changed,
    you are welcome to reapply in the future.

    — #{brand_name()} Operations
    """)
    |> html_body("""
    <!DOCTYPE html>
    <html>
    <body style="background:#010101;color:#fff;font-family:ui-monospace,monospace;padding:40px 20px;margin:0;">
      <div style="max-width:560px;margin:0 auto;">
        <div style="border-bottom:1px solid #ffffff10;padding-bottom:24px;margin-bottom:32px;">
          <span style="font-size:11px;letter-spacing:0.3em;text-transform:uppercase;color:#34d399;font-weight:700;">#{brand_name_upper()} · INSTITUTIONAL TREASURY</span>
        </div>
        <h1 style="font-size:22px;font-weight:700;margin:0 0 8px;">NOT APPROVED AT THIS TIME</h1>
        <p style="font-size:12px;color:#71717a;margin:0 0 32px;letter-spacing:0.1em;text-transform:uppercase;">Access Request Update</p>
        <p style="font-size:13px;color:#d4d4d8;line-height:1.6;">#{name},</p>
        <p style="font-size:13px;color:#d4d4d8;line-height:1.6;">
          Thank you for your interest in #{brand_name()}. After careful review, we are unable
          to approve your access request at this time.
        </p>
        #{if reason do
      """
      <div style="margin:32px 0;padding:20px;background:#ffffff04;border:1px solid #ffffff10;border-radius:12px;">
        <p style="font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:0.25em;color:#52525b;margin:0 0 8px;">Reason</p>
        <p style="font-size:13px;color:#a1a1aa;margin:0;line-height:1.6;">#{reason}</p>
      </div>
      """
    else
      ""
    end}
        <p style="font-size:13px;color:#d4d4d8;line-height:1.6;">
          If your circumstances change or you have additional information to provide,
          you are welcome to submit a new request in the future.
        </p>
        <p style="font-size:11px;color:#3f3f46;margin-top:48px;letter-spacing:0.1em;">#{brand_name_upper()} OPERATIONS · AUTOMATED NOTIFICATION</p>
      </div>
    </body>
    </html>
    """)
    |> Mailer.deliver()
  end
end
