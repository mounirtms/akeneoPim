<?php

namespace App\Controller;

use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\Routing\Annotation\Route;

class GraphQLTestController extends AbstractController
{
    #[Route('/test-graphql-route', name: 'test_graphql_route')]
    public function testRoute(): JsonResponse
    {
        return new JsonResponse([
            'status' => 'success',
            'message' => 'Route is working'
        ]);
    }
}