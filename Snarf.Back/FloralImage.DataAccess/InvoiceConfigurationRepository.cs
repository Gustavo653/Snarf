using FloralImage.Domain.Entities;
using FloralImage.Infrastructure.Repository;
using FloralImage.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace FloralImage.DataAccess
{
    public class InvoiceConfigurationRepository(FloralImageContext context) : BaseRepository<InvoiceConfiguration, FloralImageContext>(context), IInvoiceConfigurationRepository
    {
        public async Task<int> GetAndIncrementNextNumberAsync()
        {
            using (IDbContextTransaction transaction = await context.Database.BeginTransactionAsync())
            {
                try
                {
                    var invoiceConfig = await context.InvoiceConfigurations.FirstOrDefaultAsync() ?? throw new InvalidOperationException("Invoice configuration not found.");
                    int currentNextNumber = invoiceConfig.NextNumber;
                    invoiceConfig.NextNumber++;
                    await context.SaveChangesAsync();
                    await transaction.CommitAsync();
                    return currentNextNumber;
                }
                catch
                {
                    await transaction.RollbackAsync();
                    throw;
                }
            }
        }
    }
}
