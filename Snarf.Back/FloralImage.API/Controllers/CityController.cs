using FloralImage.Infrastructure.Service;
using FloralImage.Utils;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.OutputCaching;

namespace FloralImage.API.Controllers
{
    public class CityController(ICityService cityService) : BaseController
    {
        [HttpGet("GetCitiesByState/{stateId:Guid}")]
        [OutputCache(PolicyName = Consts.CacheName, Duration = Consts.CacheTimeout, VaryByHeaderNames = ["Authorization"])]
        public async Task<IActionResult> GetCitiesByState([FromRoute] Guid stateId)
        {
            var city = await cityService.GetCitiesByState(stateId);
            return StatusCode(city.Code, city);
        }
    }
}