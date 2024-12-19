using Microsoft.AspNetCore.Http;

namespace FloralImage.Infrastructure.Service
{
    public interface ISantanderService
    {
        Task<string?> CreateBankSlip(Guid invoiceId);
        Task<string?> CancelBankSlip(Guid invoiceId);
        Task<byte[]> GetPDFBankSlip(Guid invoiceId);
        Task CheckStatusBankSlip(Guid invoiceId);
    }
}
