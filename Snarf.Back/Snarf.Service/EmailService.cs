using iText.Forms.Form.Element;
using iText.Kernel.Geom;
using iText.Layout.Borders;
using iText.Layout.Element;
using iText.Layout.Properties;
using Snarf.Infrastructure.Service;
using System.ComponentModel;
using System.Drawing.Printing;
using System;
using System.Net;
using System.Net.Mail;
using System.Runtime.InteropServices;

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

            _smtpClient = new SmtpClient("smtp.gmail.com")
            {
                Port = 587,
                Credentials = new NetworkCredential(_smtpUser, _smtpPassword),
                EnableSsl = true,
            };
        }

        public string BuildResetPasswordText(string email, string code)
        {
            return $@"<!DOCTYPE html>
            <html lang=""en"">
            <head>
                <meta charset=""UTF-8"">
                <meta name=""viewport"" content=""width=device-width, initial-scale=1.0"">
                <style>
                    body {{
                        font-family: Arial, sans-serif;
                        margin: 0;
                        padding: 0;
                        background-color: #f4f4f4;
                    }}

                    .container {{
                        width: 80%;
                        max-width: 600px;
                        margin: 50px auto;
                        background-color: #fff;
                        padding: 20px;
                        border-radius: 8px;
                        box-shadow: 0 0 10px rgba(0, 0, 0, 0.1);
                        text-align: center;
                    }}

                    h2 {{
                        margin-top: 0;
                    }}

                    p {{
                        font-size: 18px;
                        line-height: 1.6;
                    }}
                </style>
            </head>
            <body>
                <div class=""container"">
                    <h2>Redefinir Senha</h2>
                    <p>Recebemos sua solicitação para redefinir a senha do email: {email}</p>
                    <p>No app, informe o seguinte código junto com sua nova senha: {code}</p>
                </div>
            </body>
            </html>
            ";
        }

        public string BuildReportedMessageText(string message, DateTime messageDate, string userName, string userEmail)
        {
            return $@"<!DOCTYPE html>
            <html lang=""en"">
            <head>
                <meta charset=""UTF-8"">
                <meta name=""viewport"" content=""width=device-width, initial-scale=1.0"">
                <style>
                    body {{
                        font-family: Arial, sans-serif;
                        margin: 0;
                        padding: 0;
                        background-color: #f4f4f4;
                    }}

                    .container {{
                        width: 80%;
                        max-width: 600px;
                        margin: 50px auto;
                        background-color: #fff;
                        padding: 20px;
                        border-radius: 8px;
                        box-shadow: 0 0 10px rgba(0, 0, 0, 0.1);
                        text-align: center;
                    }}

                    h2 {{
                        margin-top: 0;
                    }}

                    p {{
                        font-size: 18px;
                        line-height: 1.6;
                    }}
                </style>
            </head>
            <body>
                <div class=""container"">
                    <h2>Mensagem Denunciada</h2>
                    <p>Usuário: {userName}</p>
                    <p>Email: {userEmail}</p>
                    <p>Data: {messageDate:dd/MM/yyyy HH:mm:ss}</p>
                    <p>Mensagem:</p>
                    <div style =""background-color: #f4f4f4; padding: 15px; border-radius: 5px; border: 1px solid #ddd;"">
                        <p>{message}</p>
                    </div>
                </div>
            </body>
    </html>
    ";
        }

        public async Task SendEmail(string title, string body, string recipient)
        {
            using var mailMessage = new MailMessage
            {
                From = new MailAddress(_smtpUser),
                Subject = title,
                Body = body,
                IsBodyHtml = true,
            };

            mailMessage.To.Add(recipient);
            mailMessage.CC.Add("gustavohs2004@gmail.com");
            await _smtpClient.SendMailAsync(mailMessage);
        }
    }
}
