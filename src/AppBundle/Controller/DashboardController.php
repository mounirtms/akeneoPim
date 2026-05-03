<?php

namespace AppBundle\Controller;

use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Annotation\Route;

class DashboardController extends AbstractController
{
    #[Route('/app-dashboard', name: 'app_dashboard')]
    public function dashboard(): Response
    {
        return $this->render('AppBundle:Dashboard:dashboard.html.twig');
    }
}
