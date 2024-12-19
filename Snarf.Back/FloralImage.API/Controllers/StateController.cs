using FloralImage.Infrastructure.Service;
using FloralImage.Utils;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.OutputCaching;

namespace FloralImage.API.Controllers
{
    public class StateController(IStateService stateService) : BaseController
    {
        [HttpGet("GetStates")]
        [OutputCache(PolicyName = Consts.CacheName, Duration = Consts.CacheTimeout, VaryByHeaderNames = ["Authorization"])]
        public async Task<IActionResult> GetStates()
        {
            var state = await stateService.GetStates();
            return StatusCode(state.Code, state);
        }

        [HttpPost("SyncLocations")]
        [AllowAnonymous]
        public async Task<IActionResult> SyncLocations()
        {
            var state = await stateService.SyncStates();
            return StatusCode(state.Code, state);
        }
    }
}