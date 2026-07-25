import { Controller, Post, Body, Get, Param, Patch } from '@nestjs/common';
import { InventoryService } from './inventory.service';

@Controller('inventory')
export class InventoryController {
  constructor(private readonly inventoryService: InventoryService) {}

  @Post('purchase-orders')
  createPO(@Body() data: any) {
    return this.inventoryService.createPurchaseOrder(data);
  }

  @Get('purchase-orders')
  async getAllPOs() {
    const purchase_orders = await this.inventoryService.findAllPOs();
    return { success: true, purchase_orders };
  }

  @Get('get_purchase_orders')
  async getPurchaseOrders() {
    const purchase_orders = await this.inventoryService.findAllPOs();
    return { success: true, purchase_orders };
  }

  @Patch('purchase-orders/:id/receive')
  async receivePO(@Param('id') id: string) {
    return this.inventoryService.receivePurchaseOrder(+id);
  }

  @Get('get_reorder_list')
  async getReorderList() {
    const products = await this.inventoryService.getReorderList();
    return { success: true, products };
  }
}
