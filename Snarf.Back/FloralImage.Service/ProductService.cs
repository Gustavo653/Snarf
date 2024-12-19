using FloralImage.Domain.Entities;
using FloralImage.DTO;
using FloralImage.DTO.Base;
using FloralImage.Infrastructure.Repository;
using FloralImage.Infrastructure.Service;
using Microsoft.EntityFrameworkCore;
using Serilog;

namespace FloralImage.Service
{
    public class ProductService(IProductRepository productRepository, IInvoiceItemRepository invoiceItemRepository) : IProductService
    {
        public async Task<ResponseDTO> Create(ProductDTO productDTO)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var product = new Product()
                {
                    Name = productDTO.Name,
                    Price = productDTO.Price,
                };
                await productRepository.InsertAsync(product);

                await productRepository.SaveChangesAsync();
                Log.Information("Produto persistido id: {id}", product.Id);
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task<ResponseDTO> Update(Guid id, ProductDTO productDTO)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var product = await productRepository.GetTrackedEntities().FirstOrDefaultAsync(c => c.Id == id);
                if (product == null)
                {
                    responseDTO.SetBadInput($"O produto {productDTO.Name} não existe!");
                    return responseDTO;
                }

                product.Name = productDTO.Name;
                product.Price = productDTO.Price;
                product.SetUpdatedAt();

                await productRepository.SaveChangesAsync();
                Log.Information("Produto persistido id: {id}", product.Id);
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task<ResponseDTO> Remove(Guid id)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var product = await productRepository.GetTrackedEntities().FirstOrDefaultAsync(c => c.Id == id);
                if (product == null)
                {
                    responseDTO.SetBadInput($"O produto com id: {id} não existe!");
                    return responseDTO;
                }

                var productHasInvoices = await invoiceItemRepository.GetEntities().Where(x => x.Product == product).AnyAsync();
                if (productHasInvoices)
                {
                    responseDTO.SetBadInput($"O produto foi utilizado em faturas e não pode ser removido!");
                    return responseDTO;
                }

                productRepository.Delete(product);
                await productRepository.SaveChangesAsync();
                Log.Information("Produto removida id: {id}", product.Id);
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task<ResponseDTO> GetList()
        {
            ResponseDTO responseDTO = new();
            try
            {
                responseDTO.Object = await productRepository.GetEntities()
                                                             .Select(x => new
                                                             {
                                                                 x.Id,
                                                                 x.Name,
                                                                 x.Price,
                                                                 x.CreatedAt,
                                                                 x.UpdatedAt
                                                             }).ToListAsync();
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }
    }
}
