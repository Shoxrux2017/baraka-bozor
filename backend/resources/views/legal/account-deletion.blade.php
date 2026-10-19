@extends('legal.layout')

@section('content')
<p>{{ $texts['inApp'] }}</p>
@if ($texts['byPhone'] !== '')
<p>{{ $texts['byPhone'] }}</p>
@endif
<p>{{ $texts['erased'] }}</p>
<p>{{ $texts['kept'] }}</p>
<p>{{ $texts['unfinished'] }}</p>
<p><a href="{{ $privacyUrl }}">{{ $texts['privacy'] }}</a></p>
@endsection
