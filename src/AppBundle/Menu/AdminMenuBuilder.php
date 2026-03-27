<?php

namespace AppBundle\Menu;

use Knp\Menu\FactoryInterface;
use Knp\Menu\ItemInterface;
use Symfony\Component\Security\Core\Authorization\AuthorizationCheckerInterface;

class AdminMenuBuilder
{
    private $factory;
    private $authorizationChecker;
    private $pimMenuProvider;

    public function __construct(
        FactoryInterface $factory,
        AuthorizationCheckerInterface $authorizationChecker,
        $pimMenuProvider = null
    ) {
        $this->factory = $factory;
        $this->authorizationChecker = $authorizationChecker;
        $this->pimMenuProvider = $pimMenuProvider;
    }

    public function mainMenu(array $options = []): ItemInterface
    {
        $menu = $this->factory->createItem('root');
        $menu->setChildrenAttribute('class', 'nav navbar-nav');

        // Add standard menu items
        $menu->addChild('Dashboard', ['route' => 'pim_dashboard_index'])
            ->setAttribute('class', 'dashboard')
            ->setExtra('icon', 'icon-home');

        // Check if PIM menu provider exists and use it for standard menu
        if ($this->pimMenuProvider && method_exists($this->pimMenuProvider, 'getMenu')) {
            $pimMenu = $this->pimMenuProvider->getMenu($menu, $options);
            if ($pimMenu instanceof ItemInterface) {
                return $pimMenu;
            }
        }

        // Add Catalog menu
        $catalog = $menu->addChild('Catalog', [
            'uri' => '#',
            'attributes' => [
                'class' => 'dropdown'
            ],
            'childrenAttributes' => [
                'class' => 'dropdown-menu'
            ]
        ]);
        $catalog->setExtra('icon', 'icon-book');
        $catalog->setExtra('translation_domain', 'messages');
        $catalog->addChild('Products', ['route' => 'pim_enrich_product_index']);
        $catalog->addChild('Categories', ['route' => 'pim_enrich_category_tree_index']);
        $catalog->addChild('Attributes', ['route' => 'pim_enrich_attribute_index']);
        $catalog->addChild('Attribute Groups', ['route' => 'pim_enrich_attribute_group_index']);
        $catalog->addChild('Families', ['route' => 'pim_enrich_family_index']);
        $catalog->addChild('Family Variants', ['route' => 'pim_enrich_family_variant_index']);

        // Add System menu
        $system = $menu->addChild('System', [
            'uri' => '#',
            'attributes' => [
                'class' => 'dropdown'
            ],
            'childrenAttributes' => [
                'class' => 'dropdown-menu'
            ]
        ]);
        $system->setExtra('icon', 'icon-cogs');
        $system->setExtra('translation_domain', 'messages');
        $system->addChild('Channels', ['route' => 'pim_settings_channel_index']);
        $system->addChild('Locales', ['route' => 'pim_settings_locale_index']);
        $system->addChild('Currencies', ['route' => 'pim_settings_currency_index']);
        $system->addChild('Users', ['route' => 'oro_user_index']);
        $system->addChild('Groups', ['route' => 'oro_user_group_index']);
        $system->addChild('Roles', ['route' => 'oro_user_role_index']);

        // Remove or properly format MAB Extensions if it exists
        // This will prevent the ugly menu display
        
        return $menu;
    }
}