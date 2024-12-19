using FloralImage.Domain.Entities;
using FloralImage.Infrastructure.Repository;
using FloralImage.Persistence;

namespace FloralImage.DataAccess
{
    public class InvoiceRepository(FloralImageContext context) : BaseRepository<Invoice, FloralImageContext>(context), IInvoiceRepository
    {
    }
}
