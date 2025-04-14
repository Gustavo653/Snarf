namespace Snarf.Infrastructure.Service
{
    public interface IEmailService
    {
        string BuildReportedMessageText(string message, DateTime messageDate, string userName, string userEmail);
        string BuildReportedUser(string userName, string userEmail);
        string BuildResetPasswordText(string email, string code);
        string BuildRemovePlaceText(string placeTitle, Guid placeId, string ownerName, string ownerEmail);
        Task SendEmail(string title, string body, string recipient);
    }
}