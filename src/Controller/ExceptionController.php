<?php

namespace App\Controller;

use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpKernel\Exception\HttpException;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;

class ExceptionController extends AbstractController
{
    public function accessDenied(AccessDeniedHttpException $exception, Request $request): Response
    {
        return $this->render('error/403.html.twig', [
            'message' => $exception->getMessage() ?? 'Access Denied - CSRF Token Invalid',
            'exception' => $exception,
            'status_code' => 403,
        ], new Response('', 403));
    }

    public function notFound(HttpException $exception, Request $request): Response
    {
        return $this->render('error/404.html.twig', [
            'message' => $exception->getMessage() ?? 'Not Found',
            'exception' => $exception,
            'status_code' => 404,
        ], new Response('', 404));
    }
}
