using FloralImage.Domain.Entities;
using FloralImage.Infrastructure.Base;

namespace FloralImage.Infrastructure.Repository
{
    public interface IInvoiceConfigurationRepository : IBaseRepository<InvoiceConfiguration>
    {
        Task<int> GetAndIncrementNextNumberAsync();
    }
}
