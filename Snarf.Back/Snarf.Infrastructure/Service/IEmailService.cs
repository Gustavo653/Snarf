namespace Snarf.Infrastructure.Service
{
    public interface IEmailService
    {
        string BuildReportedMessageText(string message, DateTime messageDate, string userName, string userEmail);
        string BuildReportedUser(string userName, string userEmail);
        string BuildResetPasswordText(string email, string code);
        Task SendEmail(string title, string body, string recipient);
    }
}