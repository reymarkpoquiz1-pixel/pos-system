import { Controller, Get, Query, ParseIntPipe } from '@nestjs/common';
import { ReviewsService } from './reviews.service';

@Controller('products')
export class ReviewsController {
  constructor(private readonly reviewsService: ReviewsService) {}

  @Get('get_reviews')
  async getReviews(@Query('product_id', ParseIntPipe) productId: number) {
    const reviews = await this.reviewsService.getReviewsByProductId(productId);
    return { success: true, reviews };
  }
}
