using Microsoft.AspNetCore.Mvc;
using Snarf.DTO;
using Snarf.Infrastructure.Service;
using System.Security.Claims;

namespace Snarf.API.Controllers
{
    public class PlaceController(IPlaceService placeService) : BaseController
    {
        [HttpPost("")]
        public async Task<IActionResult> Create([FromBody] PlaceDTO createDTO)
        {
            var whoIsCallingId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            createDTO.UserId = whoIsCallingId;
            var result = await placeService.Create(createDTO);
            return StatusCode(result.Code, result);
        }

        [HttpPut("{id:guid}")]
        public async Task<IActionResult> Update([FromRoute] Guid id, [FromBody] PlaceDTO updateDTO)
        {
            var whoIsCallingId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var result = await placeService.Update(id, updateDTO, Guid.Parse(whoIsCallingId));
            return StatusCode(result.Code, result);
        }

        [HttpDelete("{id:guid}")]
        public async Task<IActionResult> Delete([FromRoute] Guid id)
        {
            var whoIsCallingId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var result = await placeService.Delete(id, Guid.Parse(whoIsCallingId));
            return StatusCode(result.Code, result);
        }

        [HttpGet("{id:guid}")]
        public async Task<IActionResult> GetById([FromRoute] Guid id)
        {
            var result = await placeService.GetById(id);
            return StatusCode(result.Code, result);
        }

        [HttpGet("all")]
        public async Task<IActionResult> GetAll()
        {
            var result = await placeService.GetAll();
            return StatusCode(result.Code, result);
        }

        [HttpPut("{id:guid}/signal-to-remove")]
        public async Task<IActionResult> SignalToRemove([FromRoute] Guid id)
        {
            var whoIsCallingId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var result = await placeService.SignalToRemove(id, Guid.Parse(whoIsCallingId));
            return StatusCode(result.Code, result);
        }
    }
}