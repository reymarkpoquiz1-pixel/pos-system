import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ProductReview } from './entities/product-review.entity';

@Injectable()
export class ReviewsService {
  constructor(
    @InjectRepository(ProductReview)
    private readonly reviewRepository: Repository<ProductReview>,
  ) {}

  async getReviewsByProductId(productId: number) {
    return await this.reviewRepository.find({
      where: { productId },
      relations: { user: true },
      order: { createdAt: 'DESC' },
    });
  }
}
