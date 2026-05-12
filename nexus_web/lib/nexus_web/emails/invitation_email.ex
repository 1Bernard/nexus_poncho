defmodule NexusWeb.InvitationEmail do
  @moduledoc false
  import Swoosh.Email

  alias NexusWeb.Mailer

  @from_address {"Equinox Platform", "noreply@equinox.finance"}

  def send_biometric_invitation(name, email, role, magic_link) do
    new()
    |> to({name, email})
    |> from(@from_address)
    |> subject("Your Equinox Access — Anchor Your Identity")
    |> text_body(text_body(name, role, magic_link))
    |> html_body(html_body(name, role, magic_link))
    |> Mailer.deliver()
  end

  defp text_body(name, role, magic_link) do
    """
    #{name},

    Your application to Equinox has been approved. You have been provisioned as: #{role}.

    To complete onboarding, anchor your biometric identity by visiting the link below.
    This link expires in 24 hours and is single-use.

    #{magic_link}

    If you did not request access to Equinox, disregard this email.

    — The Equinox Platform Team
    """
  end

  defp html_body(name, role, magic_link) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    </head>
    <body style="margin:0;padding:0;background:#010101;font-family:'Courier New',monospace;color:#e4e4e7;">
      <table width="100%" cellpadding="0" cellspacing="0" style="background:#010101;padding:48px 24px;">
        <tr>
          <td align="center">
            <table width="560" cellpadding="0" cellspacing="0" style="background:#050508;border:1px solid rgba(255,255,255,0.06);border-radius:16px;overflow:hidden;">

              <!-- Header -->
              <tr>
                <td style="padding:40px 40px 32px;border-bottom:1px solid rgba(255,255,255,0.06);">
                  <p style="margin:0;font-size:10px;letter-spacing:0.3em;text-transform:uppercase;color:#34d399;font-weight:700;">
                    Equinox
                  </p>
                  <h1 style="margin:12px 0 0;font-size:22px;font-weight:700;color:#ffffff;letter-spacing:-0.5px;">
                    Access <span style="color:#34d399;">Granted.</span>
                  </h1>
                  <p style="margin:8px 0 0;font-size:12px;color:#71717a;letter-spacing:0.05em;">
                    Anchor your identity to complete onboarding
                  </p>
                </td>
              </tr>

              <!-- Identity block -->
              <tr>
                <td style="padding:32px 40px;">
                  <table width="100%" cellpadding="0" cellspacing="0" style="background:rgba(255,255,255,0.02);border:1px solid rgba(255,255,255,0.06);border-radius:12px;padding:24px;">
                    <tr>
                      <td style="padding:8px 0;">
                        <p style="margin:0;font-size:9px;letter-spacing:0.2em;text-transform:uppercase;color:#52525b;">Name</p>
                        <p style="margin:4px 0 0;font-size:13px;font-weight:600;color:#ffffff;">#{name}</p>
                      </td>
                    </tr>
                    <tr>
                      <td style="padding:8px 0;">
                        <p style="margin:0;font-size:9px;letter-spacing:0.2em;text-transform:uppercase;color:#52525b;">Provisioned Role</p>
                        <p style="margin:4px 0 0;font-size:13px;font-weight:600;color:#34d399;">#{role}</p>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>

              <!-- CTA -->
              <tr>
                <td style="padding:0 40px 40px;">
                  <p style="font-size:12px;color:#a1a1aa;line-height:1.7;">
                    Click the button below to anchor your biometric identity.
                    This link expires in <strong style="color:#ffffff;">24 hours</strong> and is single-use.
                  </p>
                  <table cellpadding="0" cellspacing="0" style="margin-top:24px;">
                    <tr>
                      <td style="background:#34d399;border-radius:10px;">
                        <a href="#{magic_link}" style="display:block;padding:14px 32px;font-size:11px;font-weight:700;letter-spacing:0.15em;text-transform:uppercase;color:#010101;text-decoration:none;">
                          Anchor Biometric Identity →
                        </a>
                      </td>
                    </tr>
                  </table>
                  <p style="margin-top:20px;font-size:10px;color:#3f3f46;word-break:break-all;">
                    Or copy this link: #{magic_link}
                  </p>
                </td>
              </tr>

              <!-- Footer -->
              <tr>
                <td style="padding:24px 40px;border-top:1px solid rgba(255,255,255,0.06);">
                  <p style="margin:0;font-size:10px;color:#3f3f46;letter-spacing:0.05em;">
                    If you did not request access to Equinox, disregard this email.
                  </p>
                </td>
              </tr>

            </table>
          </td>
        </tr>
      </table>
    </body>
    </html>
    """
  end
end
