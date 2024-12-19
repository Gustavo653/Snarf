using Snarf.Infrastructure.Service;
using System.Net;
using System.Net.Mail;

namespace Snarf.Service
{
    public class EmailService : IEmailService
    {
        private readonly string _smtpUser;
        private readonly string _smtpPassword;
        private readonly SmtpClient _smtpClient;

        public EmailService()
        {
            _smtpUser = Environment.GetEnvironmentVariable("SmtpUser") ?? throw new ArgumentNullException("SmtpUser variável não encontrada.");
            _smtpPassword = Environment.GetEnvironmentVariable("SmtpPassword") ?? throw new ArgumentNullException("SmtpPassword variável não encontrada.");

            _smtpClient = new SmtpClient("smtp.office365.com")
            {
                Port = 587,
                Credentials = new NetworkCredential(_smtpUser, _smtpPassword),
                EnableSsl = true,
            };
        }

        public string BuildInvoiceEmail(int invoiceNumber)
        {
            return $@"
    <!DOCTYPE html>
    <html lang=""en"">
    <head>
        <meta charset=""UTF-8"">
        <meta name=""viewport"" content=""width=device-width, initial-scale=1.0"">
        <style>
            body {{
                font-family: Arial, sans-serif;
                background-color: #f4f4f4;
                margin: 0;
                padding: 0;
            }}
            .email-container {{
                width: 100%;
                max-width: 600px;
                margin: 50px auto;
                background-color: #ffffff;
                border-radius: 8px;
                box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
                overflow: hidden;
            }}
            .email-header {{
                background-color: #0078d7;
                color: white;
                text-align: center;
                padding: 20px 0;
            }}
            .email-header h1 {{
                margin: 0;
                font-size: 24px;
            }}
            .email-body {{
                padding: 20px;
                text-align: left;
                line-height: 1.6;
            }}
            .email-body p {{
                margin: 0 0 10px;
            }}
            .email-footer {{
                background-color: #f4f4f4;
                text-align: center;
                padding: 10px;
                font-size: 12px;
                color: #888;
            }}
            .barcode-container {{
                margin-top: 20px;
                text-align: center;
                border-top: 1px solid #ddd;
                padding-top: 20px;
            }}
            .barcode {{
                font-family: monospace;
                font-size: 16px;
                letter-spacing: 2px;
                margin: 10px 0;
            }}
        </style>
    </head>
    <body>
        <div class=""email-container"">
            <div class=""email-header"">
                <h1>Fatura #{invoiceNumber}</h1>
            </div>
            <div class=""email-body"">
                <p>A/C Financeiro,</p>
                <p>Olá, tudo bem?</p>
                <p>Segue anexo o faturamento referente ao plano de assinatura de arranjo de flores.</p>
                <p>Pedimos que confirmem o recebimento deste e-mail.</p>
                <p>Permanecemos à disposição. Até breve.</p>
                <p>Equipe Floral Image</p>
            </div>
            <div class=""email-footer"">
                <p>Este é um e-mail automático. Por favor, não responda.</p>
            </div>
        </div>
    </body>
    </html>";
        }

        public async Task SendEmail(string title, string body, string recipient, IList<Attachment> attachments)
        {
            using var mailMessage = new MailMessage
            {
                From = new MailAddress(_smtpUser),
                Subject = title,
                Body = body,
                IsBodyHtml = true,
            };

            foreach (var attachment in attachments)
            {
                mailMessage.Attachments.Add(attachment);
            }

            foreach (var email in recipient.Split(';', StringSplitOptions.RemoveEmptyEntries))
            {
                //mailMessage.To.Add(email.Trim());
            }

            mailMessage.CC.Add("saopaulo@Snarf.com.br");
            mailMessage.CC.Add("gustavohs2004@gmail.com");
            await _smtpClient.SendMailAsync(mailMessage);
        }
    }
}
