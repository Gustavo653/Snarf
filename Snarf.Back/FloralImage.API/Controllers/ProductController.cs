using FloralImage.DTO;
using FloralImage.Infrastructure.Service;
using Microsoft.AspNetCore.Mvc;

namespace FloralImage.API.Controllers
{
    public class ProductController(IProductService productService) : BaseController
    {
        [HttpPost("")]
        public async Task<IActionResult> CreateProduct([FromBody] ProductDTO productDTO)
        {
            var product = await productService.Create(productDTO);
            return StatusCode(product.Code, product);
        }

        [HttpPut("{id:guid}")]
        public async Task<IActionResult> UpdateProduct([FromRoute] Guid id, [FromBody] ProductDTO productDTO)
        {
            var product = await productService.Update(id, productDTO);
            return StatusCode(product.Code, product);
        }

        [HttpDelete("{id:guid}")]
        public async Task<IActionResult> RemoveProduct([FromRoute] Guid id)
        {
            var product = await productService.Remove(id);
            return StatusCode(product.Code, product);
        }

        [HttpGet("")]
        public async Task<IActionResult> GetProducts()
        {
            var product = await productService.GetList();
            return StatusCode(product.Code, product);
        }
    }
}