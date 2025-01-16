using Amazon.S3;
using Amazon.S3.Model;

namespace Snarf.Service
{
    public class S3Service
    {
        private readonly AmazonS3Client _s3Client;
        private readonly string _bucketName;

        public S3Service()
        {
            var serviceUrl = Environment.GetEnvironmentVariable("S3ServiceUrl") ?? throw new ArgumentNullException("S3ServiceUrl variável não encontrada.");
            var accessKey = Environment.GetEnvironmentVariable("S3AccessKey") ?? throw new ArgumentNullException("S3AccessKey variável não encontrada.");
            var secretKey = Environment.GetEnvironmentVariable("S3SecretKey") ?? throw new ArgumentNullException("S3SecretKey variável não encontrada.");
            var bucketName = Environment.GetEnvironmentVariable("S3BucketName") ?? throw new ArgumentNullException("S3BucketName variável não encontrada.");

            _s3Client = new AmazonS3Client(accessKey, secretKey, new AmazonS3Config { ServiceURL = serviceUrl });
            _bucketName = bucketName;
        }

        public async Task<string> UploadFileAsync(string key, Stream fileStream, string contentType)
        {
            var request = new PutObjectRequest
            {
                BucketName = _bucketName,
                Key = key,
                InputStream = fileStream,
                ContentType = contentType,
                CannedACL = S3CannedACL.PublicRead
            };

            await _s3Client.PutObjectAsync(request);
            return $"{_s3Client.Config.ServiceURL.Replace("https://", $"https://{_bucketName}.")}{key}";
        }

        public async Task DeleteFileAsync(string url)
        {
            var key = ExtractKeyFromUrl(url);
            var request = new DeleteObjectRequest
            {
                BucketName = _bucketName,
                Key = key
            };

            await _s3Client.DeleteObjectAsync(request);
        }

        private string ExtractKeyFromUrl(string url)
        {
            var uri = new Uri(url);
            var path = uri.AbsolutePath;
            return path.TrimStart('/');
        }
    }
}