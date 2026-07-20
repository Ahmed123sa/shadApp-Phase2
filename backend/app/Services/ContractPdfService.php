<?php

namespace App\Services;

use App\Models\Contract;
use App\Models\SystemSetting;
use Mpdf\Mpdf;
use Illuminate\Support\Facades\Storage;

class ContractPdfService
{
    private function buildPdf(Contract $contract, bool $bothSignatures): string
    {
        $client = $contract->workspace->client;
        $isImage = $client->signature_data && (str_starts_with($client->signature_data, '/storage/') || str_starts_with($client->signature_data, 'http'));

        $clientImagePath = null;
        if ($isImage) {
            $relative = str_replace('/storage/', '', $client->signature_data);
            $full = storage_path('app/public/' . $relative);
            $clientImagePath = file_exists($full) ? $full : null;
        }

        $requiredDocs = $contract->requiredDocuments()->get();

        $taxPercentage = 0;
        $taxAmount = 0;
        if ($client->client_type === 'business' && $contract->value > 0) {
            try {
                $taxPercentage = (float) SystemSetting::getValue('corporate_tax_percentage', 0);
            } catch (\Exception $e) {
                $taxPercentage = 0;
            }
            $taxAmount = (float) $contract->value * $taxPercentage / 100;
        }

        $html = view('pdf.contract', [
            'contract' => $contract,
            'client' => $client,
            'manager' => $contract->creator,
            'clientSignature' => $client->signature_data,
            'clientSignatureIsImage' => $isImage,
            'clientImagePath' => $clientImagePath,
            'companySignature' => $bothSignatures
                ? ($contract->company_signature_data ?? ($contract->creator?->name ?? 'تم الاعتماد'))
                : null,
            'requiredDocuments' => $requiredDocs,
            'taxPercentage' => $taxPercentage,
            'taxAmount' => $taxAmount,
        ])->render();

        $mpdf = new Mpdf([
            'default_font' => 'dejavusans',
            'mode' => 'ar',
            'autoArabic' => true,
            'format' => 'A4',
            'margin_top' => 10,
            'margin_bottom' => 20,
            'margin_left' => 10,
            'margin_right' => 10,
        ]);
        $mpdf->WriteHTML($html);

        $suffix = $bothSignatures ? '-signed' : '-client-signed';
        $filename = 'contract-' . $contract->id . $suffix . '.pdf';
        $path = 'contracts/' . $filename;
        Storage::disk('public')->put($path, $mpdf->Output('', 'S'));

        $contract->update(['pdf_url' => Storage::url($path)]);

        return Storage::url($path);
    }

    public function generateWithClientSignature(Contract $contract): string
    {
        return $this->buildPdf($contract, false);
    }

    public function generateWithBothSignatures(Contract $contract): string
    {
        return $this->buildPdf($contract, true);
    }
}
