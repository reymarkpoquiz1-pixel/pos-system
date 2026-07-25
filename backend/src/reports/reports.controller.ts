import { Controller, Get } from '@nestjs/common';
import { ReportsService } from './reports.service';

@Controller('reports')
export class ReportsController {
  constructor(private readonly reportsService: ReportsService) {}

  @Get('get_analytics_summary')
  async getAnalyticsSummary() {
    const data = await this.reportsService.getAnalyticsSummary();
    return { success: true, data };
  }

  @Get('get_chart_data')
  async getChartData() {
    const data = await this.reportsService.getChartData();
    return { success: true, data };
  }

  @Get('get_top_selling')
  async getTopSelling() {
    const products = await this.reportsService.getTopSelling();
    return { success: true, products };
  }

  @Get('get_sales_prediction')
  async getSalesPrediction() {
    const data = await this.reportsService.getSalesPrediction();
    return { success: true, prediction: data.predicted_sales };
  }
}
