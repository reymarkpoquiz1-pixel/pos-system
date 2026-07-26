import { Controller, Post, Body, Get, Req } from '@nestjs/common';
import { CategoriesService } from './categories.service';
import type { Request } from 'express';

@Controller('category')
export class CategoriesController {
  constructor(private readonly categoriesService: CategoriesService) {}

  @Post('add_category')
  async addCategory(@Body() data: any, @Req() req: any) {
    const ip = req.ip || '0.0.0.0';
    return this.categoriesService.addCategory(data, ip);
  }

  @Post('update_category')
  async updateCategory(@Body() data: any, @Req() req: any) {
    const ip = req.ip || '0.0.0.0';
    return this.categoriesService.updateCategory(data, ip);
  }

  @Post('delete_category')
  async deleteCategory(
    @Body() data: { id: number; user_id: number },
    @Req() req: any,
  ) {
    const ip = req.ip || '0.0.0.0';
    return this.categoriesService.deleteCategory(data.id, data.user_id, ip);
  }

  @Post('restore_category')
  async restoreCategory(
    @Body() data: { id: number; user_id: number },
    @Req() req: any,
  ) {
    const ip = req.ip || '0.0.0.0';
    return this.categoriesService.restoreCategory(data.id, data.user_id, ip);
  }

  @Get('get_categories')
  async getCategories() {
    const categories = await this.categoriesService.findAll();
    return {
      success: true,
      categories,
    };
  }

  @Get('get_category_history')
  async getCategoryHistory(@Req() req: any) {
    const categoryId = req.query.category_id;
    const history =
      await this.categoriesService.getCategoryHistory(+categoryId);
    return {
      success: true,
      history,
    };
  }
}
