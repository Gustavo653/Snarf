using FloralImage.DTO;
using FloralImage.DTO.Base;

namespace FloralImage.Infrastructure.Service
{
    public interface IInvoiceService
    {
        Task<byte[]> GeneratePdfByInvoiceId(Guid id);
        Task<byte[]> GenerateZipPdfByDate(DateTime startDate, DateTime endDate);
        Task<string> GenerateReportByDate(DateTime startDate, DateTime endDate);
        Task<ResponseDTO> GetInvoices(DateTime startDate, DateTime endDate);
        Task<ResponseDTO> BillInvoice(Guid id);
        Task<ResponseDTO> CancelInvoice(Guid id);
        Task<ResponseDTO> GetInvoiceById(Guid id);
        Task<ResponseDTO> SaveInvoice(Guid? id, InvoiceDTO invoiceDTO);
        Task GenerateInvoicesByCustomers();
        Task ValidateBills();
    }
}