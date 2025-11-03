<?php

namespace Pimcore\Model\DataObject;

use Pimcore\Model\DataObject\AbstractObject;
use Pimcore\Model\DataObject\ClassDefinition\Data\Input;
use Pimcore\Model\DataObject\ClassDefinition\Data\Textarea;
use Pimcore\Model\DataObject\ClassDefinition\Data\Select;
use Pimcore\Model\DataObject\ClassDefinition\Data\Numeric;
use Pimcore\Model\DataObject\ClassDefinition\Data\Checkbox;
use Pimcore\Model\DataObject\ClassDefinition\Data\Date;

class Product extends AbstractObject
{
    /**
     * @var string
     */
    protected $sku;

    /**
     * @var string
     */
    protected $name;

    /**
     * @var string
     */
    protected $description;

    /**
     * @var string
     */
    protected $shortDescription;

    /**
     * @var float
     */
    protected $price;

    /**
     * @var float
     */
    protected $specialPrice;

    /**
     * @var \Carbon\Carbon
     */
    protected $specialPriceFrom;

    /**
     * @var \Carbon\Carbon
     */
    protected $specialPriceTo;

    /**
     * @var string
     */
    protected $status;

    /**
     * @var int
     */
    protected $quantity;

    /**
     * @var bool
     */
    protected $isInStock;

    /**
     * @var string
     */
    protected $metaTitle;

    /**
     * @var string
     */
    protected $metaDescription;

    /**
     * @var array
     */
    protected $categories;

    /**
     * @var string
     */
    protected $brand;

    /**
     * @var float
     */
    protected $weight;

    /**
     * @return string|null
     */
    public function getSku(): ?string
    {
        return $this->sku;
    }

    /**
     * @param string|null $sku
     * @return $this
     */
    public function setSku(?string $sku): static
    {
        $this->sku = $sku;
        return $this;
    }

    /**
     * @return string|null
     */
    public function getName(): ?string
    {
        return $this->name;
    }

    /**
     * @param string|null $name
     * @return $this
     */
    public function setName(?string $name): static
    {
        $this->name = $name;
        return $this;
    }

    /**
     * @return string|null
     */
    public function getDescription(): ?string
    {
        return $this->description;
    }

    /**
     * @param string|null $description
     * @return $this
     */
    public function setDescription(?string $description): static
    {
        $this->description = $description;
        return $this;
    }

    /**
     * @return string|null
     */
    public function getShortDescription(): ?string
    {
        return $this->shortDescription;
    }

    /**
     * @param string|null $shortDescription
     * @return $this
     */
    public function setShortDescription(?string $shortDescription): static
    {
        $this->shortDescription = $shortDescription;
        return $this;
    }

    /**
     * @return float|null
     */
    public function getPrice(): ?float
    {
        return $this->price;
    }

    /**
     * @param float|null $price
     * @return $this
     */
    public function setPrice(?float $price): static
    {
        $this->price = $price;
        return $this;
    }

    /**
     * @return float|null
     */
    public function getSpecialPrice(): ?float
    {
        return $this->specialPrice;
    }

    /**
     * @param float|null $specialPrice
     * @return $this
     */
    public function setSpecialPrice(?float $specialPrice): static
    {
        $this->specialPrice = $specialPrice;
        return $this;
    }

    /**
     * @return \Carbon\Carbon|null
     */
    public function getSpecialPriceFrom(): ?\Carbon\Carbon
    {
        return $this->specialPriceFrom;
    }

    /**
     * @param \Carbon\Carbon|null $specialPriceFrom
     * @return $this
     */
    public function setSpecialPriceFrom(?\Carbon\Carbon $specialPriceFrom): static
    {
        $this->specialPriceFrom = $specialPriceFrom;
        return $this;
    }

    /**
     * @return \Carbon\Carbon|null
     */
    public function getSpecialPriceTo(): ?\Carbon\Carbon
    {
        return $this->specialPriceTo;
    }

    /**
     * @param \Carbon\Carbon|null $specialPriceTo
     * @return $this
     */
    public function setSpecialPriceTo(?\Carbon\Carbon $specialPriceTo): static
    {
        $this->specialPriceTo = $specialPriceTo;
        return $this;
    }

    /**
     * @return string|null
     */
    public function getStatus(): ?string
    {
        return $this->status;
    }

    /**
     * @param string|null $status
     * @return $this
     */
    public function setStatus(?string $status): static
    {
        $this->status = $status;
        return $this;
    }

    /**
     * @return int|null
     */
    public function getQuantity(): ?int
    {
        return $this->quantity;
    }

    /**
     * @param int|null $quantity
     * @return $this
     */
    public function setQuantity(?int $quantity): static
    {
        $this->quantity = $quantity;
        return $this;
    }

    /**
     * @return bool|null
     */
    public function getIsInStock(): ?bool
    {
        return $this->isInStock;
    }

    /**
     * @param bool|null $isInStock
     * @return $this
     */
    public function setIsInStock(?bool $isInStock): static
    {
        $this->isInStock = $isInStock;
        return $this;
    }

    /**
     * @return string|null
     */
    public function getMetaTitle(): ?string
    {
        return $this->metaTitle;
    }

    /**
     * @param string|null $metaTitle
     * @return $this
     */
    public function setMetaTitle(?string $metaTitle): static
    {
        $this->metaTitle = $metaTitle;
        return $this;
    }

    /**
     * @return string|null
     */
    public function getMetaDescription(): ?string
    {
        return $this->metaDescription;
    }

    /**
     * @param string|null $metaDescription
     * @return $this
     */
    public function setMetaDescription(?string $metaDescription): static
    {
        $this->metaDescription = $metaDescription;
        return $this;
    }

    /**
     * @return array|null
     */
    public function getCategories(): ?array
    {
        return $this->categories;
    }

    /**
     * @param array|null $categories
     * @return $this
     */
    public function setCategories(?array $categories): static
    {
        $this->categories = $categories;
        return $this;
    }

    /**
     * @return string|null
     */
    public function getBrand(): ?string
    {
        return $this->brand;
    }

    /**
     * @param string|null $brand
     * @return $this
     */
    public function setBrand(?string $brand): static
    {
        $this->brand = $brand;
        return $this;
    }

    /**
     * @return float|null
     */
    public function getWeight(): ?float
    {
        return $this->weight;
    }

    /**
     * @param float|null $weight
     * @return $this
     */
    public function setWeight(?float $weight): static
    {
        $this->weight = $weight;
        return $this;
    }
}