import { Injectable } from '@nestjs/common';
import { v2 as cloudinary } from 'cloudinary';
import { CloudinaryResponse } from './cloudinary-response';
import * as streamifier from 'streamifier';

@Injectable()
export class CloudinaryService {
  uploadFile(file: Express.Multer.File): Promise<CloudinaryResponse> {
    return new Promise<CloudinaryResponse>((resolve, reject) => {
      const uploadStream = cloudinary.uploader.upload_stream(
        {
          folder: 'pos_products',
        },
        (error, result) => {
          if (error) return reject(new Error(error.message || 'Cloudinary upload failed'));
          if (!result)
            return reject(new Error('Cloudinary upload failed: Empty result'));
          resolve(result);
        },
      );

      streamifier.createReadStream(file.buffer).pipe(uploadStream);
    });
  }

  async uploadBase64(
    base64String: string,
    folder: string,
  ): Promise<CloudinaryResponse> {
    return new Promise((resolve, reject) => {
      // Remove data:image/xxx;base64, prefix if present
      const cleanBase64 = base64String.replace(/^data:image\/\w+;base64,/, '');

      cloudinary.uploader.upload(
        `data:image/png;base64,${cleanBase64}`,
        { folder },
        (error, result) => {
          if (error) return reject(new Error(error.message || 'Cloudinary upload failed'));
          if (!result)
            return reject(new Error('Cloudinary upload failed: Empty result'));
          resolve(result);
        },
      );
    });
  }
}
