import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Wishlist } from './entities/wishlist.entity';

@Injectable()
export class WishlistService {
  constructor(
    @InjectRepository(Wishlist)
    private readonly wishlistRepository: Repository<Wishlist>,
  ) {}

  async getWishlistByUserId(userId: number) {
    return await this.wishlistRepository.find({
      where: { userId },
      relations: { product: true },
      order: { createdAt: 'DESC' },
    });
  }
}
