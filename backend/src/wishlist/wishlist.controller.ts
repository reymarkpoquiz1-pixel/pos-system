import { Controller, Get, Query, ParseIntPipe } from '@nestjs/common';
import { WishlistService } from './wishlist.service';

@Controller('products')
export class WishlistController {
  constructor(private readonly wishlistService: WishlistService) {}

  @Get('get_wishlist')
  async getWishlist(@Query('user_id', ParseIntPipe) userId: number) {
    const wishlist = await this.wishlistService.getWishlistByUserId(userId);
    return { success: true, wishlist };
  }
}
