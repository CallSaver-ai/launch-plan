import OpenAI from 'openai';
import { z } from 'zod';
import { zodTextFormat } from 'openai/helpers/zod';

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

// Simple test schema
const TestSchema = z.object({
  businessName: z.string(),
  services: z.array(z.string()),
  confidence: z.number(),
});

async function testResponsesAPI() {
  console.log('Testing Responses API with gpt-4o-mini...\n');
  
  try {
    const response = await openai.responses.parse({
      model: 'gpt-4o-mini',
      input: [
        { role: 'system', content: 'Extract business information from the text.' },
        { role: 'user', content: 'Acme Plumbing offers drain cleaning, pipe repair, and water heater installation. They are a trusted local business.' }
      ],
      text: {
        format: zodTextFormat(TestSchema, 'business_info'),
      },
    });

    console.log('✅ Responses API success!');
    console.log('Output:', JSON.stringify(response.output, null, 2));
    
    // Check for parsed content
    for (const output of response.output) {
      if (output.type === 'message') {
        for (const item of output.content) {
          if (item.type === 'output_text' && item.parsed) {
            console.log('\nParsed data:', JSON.stringify(item.parsed, null, 2));
          }
        }
      }
    }
    
    return true;
  } catch (error: any) {
    console.error('❌ Responses API failed:', error.message);
    console.error(error);
    return false;
  }
}

testResponsesAPI();
