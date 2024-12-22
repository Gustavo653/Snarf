namespace Snarf.Infrastructure.Service
{
    public interface IEmailService
    {
        string BuildResetPasswordText(string email, string code);
        Task SendEmail(string title, string body, string recipient);
    }
}