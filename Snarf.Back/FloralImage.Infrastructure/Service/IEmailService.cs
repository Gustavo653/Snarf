using System.Net.Mail;

namespace FloralImage.Infrastructure.Service
{
    public interface IEmailService
    {
        string BuildInvoiceEmail(int invoiceNumber);
        Task SendEmail(string title, string body, string recipient, IList<Attachment> attachments);
    }
}