<?php

namespace AppBundle\Component\Shipping\Yalidine;

use Akeneo\Shipping\CarrierInterface;
use Akeneo\Shipping\Model\Carrier\Carrier as BaseCarrier;
use Akeneo\Shipping\Model\Parcel\ParcelInterface;

class Carrier extends BaseCarrier implements CarrierInterface
{
    const CARRIER_CODE = 'yalidine';
    
    /**
     * {@inheritdoc}
     */
    public function getCode(): string
    {
        return self::CARRIER_CODE;
    }
    
    /**
     * {@inheritdoc}
     */
    public function getTitle(): string
    {
        return 'Yalidine';
    }
    
    /**
     * {@inheritdoc}
     */
    public function isActive(): bool
    {
        return true;
    }
    
    /**
     * {@inheritdoc}
     */
    public function getAllowedMethods(): array
    {
        return [
            'home_delivery' => 'Home Delivery',
            'pickup_point' => 'Pickup Point',
            'express' => 'Express Delivery'
        ];
    }
    
    /**
     * {@inheritdoc}
     */
    public function calculatePrice(ParcelInterface $parcel): float
    {
        // Basic price calculation - in a real implementation this would connect to Yalidine API
        $weight = $parcel->getWeight();
        $method = $parcel->getShippingMethod();
        
        switch ($method) {
            case 'express':
                return 500 + ($weight * 10);
            case 'pickup_point':
                return 200 + ($weight * 5);
            case 'home_delivery':
            default:
                return 300 + ($weight * 7);
        }
    }
    
    /**
     * {@inheritdoc}
     */
    public function validateAddress(array $address): bool
    {
        // Basic address validation
        $requiredFields = ['street', 'city', 'postcode', 'country'];
        foreach ($requiredFields as $field) {
            if (!isset($address[$field]) || empty($address[$field])) {
                return false;
            }
        }
        
        return true;
    }
    
    /**
     * {@inheritdoc}
     */
    public function getTrackingUrl(string $trackingNumber): string
    {
        return 'https://www.yalidine.com/track/' . $trackingNumber;
    }
}