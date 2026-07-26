import {
  Controller,
  Post,
  Body,
  Req,
  UseInterceptors,
  UploadedFiles,
  Get,
} from '@nestjs/common';
import { ProductsService } from './products.service';
import { CloudinaryService } from '../cloudinary/cloudinary.service';
import type { Request } from 'express';
import { FilesInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';

@Controller('products')
export class ProductsController {
  constructor(
    private readonly productsService: ProductsService,
    private readonly cloudinaryService: CloudinaryService,
  ) {}

  @Post('add_product')
  @UseInterceptors(
    FilesInterceptor('images[]', 10, {
      storage: memoryStorage(),
    }),
  )
  async addProduct(
    @Body() data: any,
    @UploadedFiles() files: Express.Multer.File[],
    @Req() req: any,
  ) {
    const ip = req.ip || '0.0.0.0';

    // Combine existing images with newly uploaded ones
    let finalImages: string[] = [];

    if (data.existing_images) {
      try {
        finalImages =
          typeof data.existing_images === 'string'
            ? JSON.parse(data.existing_images)
            : data.existing_images;
      } catch (e) {
        finalImages = [];
      }
    }

    if (files && files.length > 0) {
      // Upload each file to Cloudinary
      const uploadPromises = files.map((file) =>
        this.cloudinaryService.uploadFile(file),
      );
      const results = await Promise.all(uploadPromises);
      const newFileUrls = results.map((res) => res.secure_url);
      finalImages = [...finalImages, ...newFileUrls];
    }

    data.images = finalImages;

    return this.productsService.upsertProduct(data, ip);
  }

  @Get('get_products')
  async getProducts() {
    const products = await this.productsService.findAll();
    return {
      success: true,
      products,
    };
  }

  @Get('get_stock_history')
  async getStockHistory(@Req() req: any) {
    const productId = req.query.product_id;
    const history = await this.productsService.getStockHistory(+productId);
    return {
      success: true,
      history,
    };
  }
}
