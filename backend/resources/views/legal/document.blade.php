@extends('legal.layout')

@section('content')
@if ($edition === null)
<p>{{ $notPublished }}</p>
@else
<p class="edition">{{ $edition }}</p>
@foreach ($blocks as $block)
@if ($block['type'] === 'heading')
<h2>{{ $block['text'] }}</h2>
@elseif ($block['type'] === 'list')
<ul>
@foreach ($block['items'] as $item)
<li>{{ $item }}</li>
@endforeach
</ul>
@else
<p>{{ $block['text'] }}</p>
@endif
@endforeach
@endif
@endsection
